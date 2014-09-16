
require 'securerandom'





module DrillSergeant
  class App < Padrino::Application


    register Padrino::Mailer
    register Padrino::Helpers
    register Padrino::WebSockets

    enable :sessions


    ##
    # Caching support.
    #
    # register Padrino::Cache
    # enable :caching
    #
    # You can customize caching store engines:
    #
    # set :cache, Padrino::Cache.new(:LRUHash) # Keeps cached values in memory
    # set :cache, Padrino::Cache.new(:Memcached) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Memcached, '127.0.0.1:11211', :exception_retry_limit => 1)
    # set :cache, Padrino::Cache.new(:Memcached, :backend => memcached_or_dalli_instance)
    # set :cache, Padrino::Cache.new(:Redis) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Redis, :host => '127.0.0.1', :port => 6379, :db => 0)
    # set :cache, Padrino::Cache.new(:Redis, :backend => redis_instance)
    # set :cache, Padrino::Cache.new(:Mongo) # Uses default server at localhost
    # set :cache, Padrino::Cache.new(:Mongo, :backend => mongo_client_instance)
    # set :cache, Padrino::Cache.new(:File, :dir => Padrino.root('tmp', app_name.to_s, 'cache')) # default choice
    #

    ##
    # Application configuration options.
    #
    # set :raise_errors, true       # Raise exceptions (will stop application) (default for test)
    # set :dump_errors, true        # Exception backtraces are written to STDERR (default for production/development)
    # set :show_exceptions, true    # Shows a stack trace in browser (default for development)
    # set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
    # set :public_folder, 'foo/bar' # Location for static assets (default root/public)
    # set :reload, false            # Reload application files (default in development)
    # set :default_builder, 'foo'   # Set a custom form builder (default 'StandardFormBuilder')
    # set :locale_path, 'bar'       # Set path for I18n translations (default your_apps_root_path/locale)
    # disable :sessions             # Disabled sessions by default (enable if needed)
    # disable :flash                # Disables sinatra-flash (enabled by default if Sinatra::Flash is defined)
    # layout  :my_layout            # Layout can be in views/layouts/foo.ext or views/foo.ext (default :application)
    #
    set clientCheckinCurfew: 150
    set startPageURL: 'http://localhost:18080/client_start.html'
    set data_file: 'data.yml'
    set recentactivity_file: 'recentactivity.yml'

    if File.exists?(settings.data_file)
      set dataStore: YAML.load_file(settings.data_file)
    else
      set dataStore: {}
    end
    settings.dataStore[:clients] ||= {}
    settings.dataStore[:schedules] ||= {}
    if File.exists?(settings.recentactivity_file)
      set recentActivity: YAML.load_file(settings.recentactivity_file)
    else
      set recentActivity: [] # = {timestamp: ts, event: evt, subject: sub}
    end


    at_exit do
      File.write(settings.data_file, settings.dataStore.to_yaml)
      File.write(settings.recentactivity_file, settings.recentActivity.to_yaml)
    end

    # valid events are: :checkin, :register, :display
    def LogActivity(event, subject)
      settings.recentActivity.unshift({timestamp: Time.now, event: event, subject: subject})
      while settings.recentActivity.size > 250
        settings.recentActivity.pop
      end
    end

    #SCHEDULER.shutdown(:wait) if SCHEDULER
    SCHEDULER = Rufus::Scheduler.new


    ##
    # You can configure for a specified environment like:
    #
    #   configure :development do
    #     set :foo, :bar
    #     disable :asset_stamp # no asset timestamping for dev
    #   end
    #

    ##
    # You can manage errors like:
    #
    #   error 404 do
    #     render 'errors/404'
    #   end
    #
    #   error 500 do
    #     render 'errors/500'
    #   end
    #

    get '/' do
      render :index
    end
    get '/client' do
      render :client
    end
    get '/admin' do
      render :admin
    end
    post '/admin/schedules_do' do
      if params[:s] and params[:s].eql? 'n' and params[:schedname] and not params[:schedname].eql? ''
        logger.info "Creating new schedule: #{params[:schedname]}"
        new_uid = NewSchedule(params[:schedname])
        redirect "/admin/schedules/#{new_uid}", 302
      elsif params[:s] and params[:s].eql? 'nu' and params[:schedid] and not params[:schedid].eql? ''
        if params[:url] and not params[:url].eql? '' and params[:dur] and not params[:dur].eql? ''
          logger.info "Creating new schedule (#{params[:schedid]}) URL: #{params[:url]} / #{params[:dur]}"
          AddUrlToSchedule(params[:url],params[:dur],params[:schedid])
          redirect "/admin/schedules/#{params[:schedid]}", 302
        else
          redirect "/admin/schedules/#{params[:schedid]}", 302
        end
      elsif params[:s] and params[:s].eql? 'du' and params[:schedid] and not params[:schedid].eql? '' and params[:urlid] and not params[:urlid].eql? ''
        logger.info "Deleting schedule (#{params[:schedid]}) URL: #{params[:urlid]}}"
        RemoveUrlFromSchedule(params[:urlid],params[:schedid])
        redirect "/admin/schedules/#{params[:schedid]}", 302
      end
      redirect '/admin/schedules#', 302
    end
    get '/admin/schedules', :with=>:id do
      @uid = params[:id]
      @schedule = settings.dataStore[:schedules][@uid]
      render :schedule_detail
    end
    get '/admin/schedules' do
      render :schedules
    end
    post '/admin/enlisted_do' do
      if params[:s].eql? 'o'
        uid = params[:id]
        url = settings.startPageURL
        dur = 0
        client = GetClient(params[:id])
        url = params[:url] if params[:url] and not params[:url].eql? ''
        dur = params[:dur].to_i if params[:dur] and not params[:dur].eql? ''
        logger.warn "Manual url change! uid=#{uid} url=#{url} dur=#{dur}"
        ManualURLOverride(uid, url, dur) if client
        redirect "/admin/enlisted/#{uid}", 302
      else
        redirect "/admin/enlisted#", 301
      end
    end
    get '/admin/enlisted', :with=>:id do
      settings.dataStore[:clients] ||= {}
      @uid = params[:id]
      @client = settings.dataStore[:clients][@uid]
      if @client
        if params[:s].eql? 'y'
          logger.info "Updating enlisted #{@uid}"
          settings.dataStore[:clients][@uid][:displayName] = params[:dn] if params[:dn]
          settings.dataStore[:clients][@uid][:assignedSchedule] = params[:sched] if params[:sched]
          redirect "/admin/enlisted/#{@uid}", 302
        elsif params[:s].eql? 'd'
          logger.info "Deleting enlisted #{@uid}"
          settings.dataStore[:clients].delete(@uid)
          redirect "/admin/enlisted#{}", 302
        else
          render :enlisted_detail
        end
      else
        redirect "/admin/enlisted#", 301
      end
    end

    get '/admin/enlisted' do
      render :enlisted
    end


    # >>> fun testing that needs to go away
    get '/admin/reload' do
      uid = params[:id]
      SendMessage(uid, {'event'=>'reload','data'=>""})
      redirect "/admin/", 303
    end
    get '/admin/gotocnn' do
      uid = params[:id]
      url = "http://cnn.com"
      SetClientURL(uid,url)
      redirect "/admin/", 303
    end
    get '/admin/gotoslashdot' do
      uid = params[:id]
      url = "http://slashdot.com"
      SetClientURL(uid,url)
      redirect "/admin/", 303
    end
    get '/admin/goback' do
      uid = params[:id]
      SetClientURLDefault(uid)
      redirect "/admin/", 303
    end
    # <<< fun testing that needs to go away

    websocket :clientcomm do
      event :ping do |message|
        logger.info "PING! #{message}"
        useragent = message["useragent"]
        display = message["display"]
        url = message["url"]
        since = message["since"]
        uid = message["uid"]
        uid = SecureRandom.uuid if not uid or uid == ""
        RegisterPing(uid, session['websocket_user'], useragent, display, url, since)
        send_message(:clientcomm, session['websocket_user'], {'event'=>'pong','data'=>{'status'=>'ok','uid'=>uid}})
      end
    end

    def ManualURLOverride(uid, url, duration)
      client = GetClient(uid)
      if client
        client[:overrideURL] = url
        client[:overrideUntil] = Time.now + duration
        SetClientURL(uid, url)
      end
    end

    def self.GetClient(uid)
      ds = DrillSergeant::App.settings.dataStore
      ds[:clients] ||= {}
      return ds[:clients][uid]
    end
    def GetClient(uid)
      return DrillSergeant::App.GetClient(uid)
    end

    def self.SyncClientURL(uid)
      client = DrillSergeant::App.GetClient(uid)
      intendedURL = GetClientAssignedURL(uid)
      currentURL = ""
      currentURL = client[:lastURL] if client[:lastURL]

      if not intendedURL.eql? currentURL
        logger.warn "Sending #{uid} to #{intendedURL}"
        SetClientURL(uid, intendedURL)
      end
    end
    def SyncClientURL(uid)
      return DrillSergeant::App.SyncClientURL(uid)
    end

    def self.GetClientAssignedURL(uid)
      startPageURL = Padrino.mounted_apps[0].app_constant.settings.startPageURL
      client = DrillSergeant::App.GetClient(uid)
      if client
        overrideUntil = nil
        overrideURL = ""
        overrideUntil = client[:overrideUntil] if client[:overrideUntil]
        overrideURL = client[:overrideURL] if client[:overrideURL]

        if overrideUntil and overrideUntil > Time.now and not overrideURL.eql? ''
          # looks like we have a legitimate override, so give up the goods
          return overrideURL
        else
          assignedURL = ""
          assignedURL = client[:assignedURL] if client[:assignedURL]
          assignedURL = startPageURL if assignedURL.eql?''
          return assignedURL
        end
        return nil
      end
    end
    def GetClientAssignedURL(uid)
      return DrillSergeant::App.GetClientAssignedURL(uid)
    end

    def NewSchedule(name)
      settings.dataStore[:schedules] ||= {}
      uid = SecureRandom.uuid
      settings.dataStore[:schedules][uid] ||= {}
      settings.dataStore[:schedules][uid][:displayName] = name
      settings.dataStore[:schedules][uid][:rotation] = {}
      return uid
    end
    def GetSchedules()
      return settings.dataStore[:schedules]
    end
    def self.GetScheduleFollowers(schedule_uid)
      ds = Padrino.mounted_apps[0].app_constant.settings.dataStore
      ret = []
      ds[:clients] ||= {}
      ds[:schedules] ||= {}
      return ret if not ds[:schedules].has_key?(schedule_uid)
      ds[:clients].each do |k,v|
        ret.push(k) if v[:assignedSchedule] and v[:assignedSchedule].eql?schedule_uid
      end
      return ret
    end
    def GetScheduleFollowers(schedule_uid)
      return DrillSergeant::App.GetScheduleFollowers(schedule_uid)
    end
    def AddUrlToSchedule(url,duration,schedule_uid)
      settings.dataStore[:schedules] ||= {}
      settings.dataStore[:schedules][schedule_uid][:rotation] ||= {}
      uid = SecureRandom.uuid
      settings.dataStore[:schedules][schedule_uid][:rotation][uid]={url: url, duration: duration}
    end
    def RemoveUrlFromSchedule(urlid,schedule_uid)
      settings.dataStore[:schedules] ||= {}
      return if not settings.dataStore[:schedules].has_key?(schedule_uid)
      settings.dataStore[:schedules][schedule_uid][:rotation] ||= {}
      settings.dataStore[:schedules][schedule_uid][:rotation].delete(urlid)
    end


    def RegisterPing(uid, socketName, userAgent, screenSize, lastURL, startTime)
      new_registration = true
      settings.dataStore[:clients] ||= {}
      new_registration = false if settings.dataStore[:clients][uid]
      settings.dataStore[:clients][uid] ||= {}
      subject_name = uid
      subject_name = settings.dataStore[:clients][uid][:displayName] if settings.dataStore[:clients][uid][:displayName] and not settings.dataStore[:clients][uid][:displayName].eql? ''
      settings.dataStore[:clients][uid][:socketName] = socketName
      settings.dataStore[:clients][uid][:userAgent] = userAgent
      settings.dataStore[:clients][uid][:screenSize] = screenSize
      new_url = false
      new_url = true if settings.dataStore[:clients][uid][:lastURL] and not settings.dataStore[:clients][uid][:lastURL].eql? lastURL
      settings.dataStore[:clients][uid][:lastURL] = lastURL
      settings.dataStore[:clients][uid][:startTime] = Time.at(startTime)
      settings.dataStore[:clients][uid][:lastCheckin] = Time.now

      #:checkin, :register, :display
      LogActivity(:register, subject_name) if new_registration
      LogActivity(:display, subject_name) if not new_registration and new_url
      LogActivity(:checkin, subject_name) if not new_registration and not new_url

      #Check if this client has an existing task to perform; if so, we should do it
      assignedTask = GetClientAssignedURL(uid)
      #SyncClientURL(uid)
      #SetClientURL(uid, assignedTask) if assignedTask and not (assignedTask.eql? lastURL or (assignedTask+'/').eql? lastURL)
    end

    def SetClientURLDefault(clientUID)
      SetClientURL(clientUID, settings.startPageURL)
    end
    def self.SetClientURL(clientUID, destURL)
      SendMessage(clientUID, {'event'=>'change_display','data'=>{'url'=>destURL}})
    end
    def SetClientURL(clientUID, destURL)
      return DrillSergeant::App.SetClientURL(clientUID, destURL)
    end
    def self.SendMessage(clientUID, msgData)
      ds = Padrino.mounted_apps[0].app_constant.settings.dataStore
      #TODO: might want to add some exception handling here, just in case they went away...
      ds[:clients] ||= {}
      socketName = nil
      socketName = ds[:clients][clientUID][:socketName] if ds[:clients][clientUID]
      begin
        logger.warn 'sending WebSockets msg'
        Padrino::WebSockets::Faye::EventManager.send_message(:clientcomm, socketName, msgData) if socketName
      rescue StandardError
        logger.error "Caught exception"
      end
    end
    def SendMessage(clientUID, msgData)
      return DrillSergeant::App.SendMessage(clientUID, msgData)
    end

    def MakeStats_ActiveEnlisted()
      total = 0
      active = 0
      settings.dataStore[:clients] ||= {}
      settings.dataStore[:clients].each do |uid,client|
        active += 1 if(Time.at(Time.now - client[:lastCheckin]).to_i < 90)
        total += 1
      end
      return [active,total]
    end

    # Update displays based on the schedules!
    class SchedulePerformer
      def self.init(app) 
        @appInst = app
      end
      def self.call()
          logger.warn "Running PerformSchedules!"
          startTime = Time.now
          startTime_i = startTime.to_i

          #logger.warn "#{settings.dataStore}"
          #logger.warn "#{@t.settings.dataStore}"
          #puts ". hello #{@appInst.settings.dataStore} at #{Time.now}"
          #puts ". hello #{self.inspect} at #{Time.now}"

          # Iterate each schedule
          # Determine the current URL for this schedule at this moment
          # Get the followers for that schedule
          # Update their current URL, if necessary

          @appInst.settings.dataStore[:schedules].each do |sched_uid,sched|
            ds = Padrino.mounted_apps[0].app_constant.settings.dataStore
            tot = 0
            sched[:rotation].values.map { |x| tot+= x[:duration].to_i }
            logger.warn "#{tot}!"
            rem = startTime_i % tot
            i = 0
            url = ""
            sched[:rotation].values.map { |x| i+= x[:duration].to_i; url=x[:url] if i>rem and url.eql?"" }
            logger.warn "#{url}!"
            rotationURL = url

            # logger.warn @appInst.inspect
            # logger.warn @appInst.class
            # logger.warn @appInst.methods.to_s

            followers = @appInst.GetScheduleFollowers(sched_uid)
            followers.each do |follower_uid|
              ds[:clients][follower_uid][:assignedURL] = rotationURL
              #follower[:assignedURL] = rotationURL
              DrillSergeant::App.SyncClientURL(follower_uid)
            end

          end
      end
    end

    # Spawn the SchedulePerformer worker thread every second
    SchedulePerformer.init(self) # this gives us access to the instance variables of App
    SCHEDULER.every "1s", SchedulePerformer
    # SCHEDULER.every "1s" do
    #         #logger.warn Padrino::Application.settings.dataStore
    #         logger.warn Padrino.mounted_apps[0].app_constant.methods.to_s
    #         logger.warn DrillSergeant::App.methods.to_s
    #         logger.warn DrillSergeant::App.GetScheduleFollowers("21cc371f-014b-4f2f-98c3-57e0ec1dbd67")
    # end


  end # class App < Padrino::Application

end # module DrillSergeant
