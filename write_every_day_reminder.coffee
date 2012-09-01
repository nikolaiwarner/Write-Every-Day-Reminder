class WriteEveryDayReminder
  constructor: (options) ->
    @version = '2.0.0'
    @available = true
    @refresh_rate = options.refresh_rate || 30 * 60 * 1000 # default, once every half hour
    @default_rss_url = options.default_rss_url || "http://750words.com/api/rss/[your id]"
    @a_day_of_seconds = 60 * 60 * 24
    @refresh_timer = undefined
    @notification = undefined

    # Events
    document.addEventListener "DOMContentLoaded", =>
      if $(".options").length > 0
        # Options
        $(".save_button").click @save_options
        @restore_options()
        setInterval (->
          @update_advanced_info()
        ), 10000
      else if $(".notification").length > 0
        # Notification
        $("#time_left").html "Less than #{@time_left_today()} left to write today."
        $(document).click window.close
      else
        # Background
        @schedule_refresh()
        @update()

        # listen_for_storage_updates
        window.addEventListener "storage", ((event) ->
          if event.key == "rss_url"
            @schedule_refresh()
            @update()
          else
            @update_interface()
        ), false

        # clickable icon
        chrome.browserAction.onClicked.addListener (tab) ->
          if @available
            chrome.tabs.create(url: "http://750words.com")
          else
            chrome.tabs.create(url: "options.html")


  fetch_from_rss_url: =>
    if localStorage["rss_url"] == undefined || localStorage["rss_url"] == @default_rss_url
      localStorage["rss_url"] = @default_rss_url
    else
      $.ajax
        url: localStorage["rss_url"]
        success: (data) =>
          @available = true
          @rss_data_response(data)

        error: =>
          @available = false
          @update_interface()


  rss_data_response: (data) =>
    latest_item_description = $(data).find("rss channel item:first description").text()
    if latest_item_description.indexOf("finished") != -1 # did you actually finish or just get started?

      # Streak
      regex = new RegExp("is on a (.*) day writing streak", "g")
      streak_array = regex.exec(latest_item_description)

      if streak_array
        localStorage["current_streak"] = parseInt(streak_array[1], 10)
      else
        localStorage["current_streak"] = "0"

      finished_date = new Date($(data).find("rss channel item:first pubDate").text())
      localStorage["last_finished_date"] = finished_date

      if @finished_today() # did you finish within today?
        localStorage["progressed_today"] = "true"
      else
        localStorage["progressed_today"] = "false"
    else
      localStorage["progressed_today"] = "false"

    # Show notification
    if localStorage["show_notification"] == "true" || localStorage["progressed_today"] == "false"
      @notification = webkitNotifications.createHTMLNotification("notification.html")
      @notification.show()
      setTimeout (=> @notification.cancel() ), 10000
    @update_interface()


  update_interface: =>
    if @available
      # Update Badge
      if localStorage["show_badge"] == "true"
        chrome.browserAction.setBadgeText(text: localStorage["current_streak"])
      else
        chrome.browserAction.setBadgeText(text: "")

      # Update Progress
      if localStorage["progressed_today"] == "true"
        chrome.browserAction.setIcon(path: "icon_success.png")
        chrome.browserAction.setBadgeBackgroundColor(color: [0, 255, 0, 255])
      else
        chrome.browserAction.setIcon(path: "icon.png")
        chrome.browserAction.setBadgeBackgroundColor(color: [255, 0, 0, 255])
    else
      chrome.browserAction.setIcon(path: "icon_unavailable.png")
      chrome.browserAction.setBadgeText(text: "")


  schedule_refresh: =>
    clearInterval(@refresh_timer) if @refresh_timer
    @refresh_timer = setInterval (=> @update() ), @refresh_rate


  update: =>
    # A simple scrape of the rss will do for now.
    # Perhaps someday there will be an official 750 words api.
    @fetch_from_rss_url()


  save_options: =>
    localStorage["show_badge"] = $("#show_badge").is(":checked")
    localStorage["show_notification"] = $("#show_notification").is(":checked")
    localStorage["rss_url"] = $("#rss_url").val()

    # Update status to let user know options were saved.
    $("#status").html("Options Saved.")
    setTimeout (=> $("#status").html("") ), 4000


  restore_options: =>
    $("#show_badge").attr("checked", (localStorage["show_badge"] == "true"))
    $("#show_notification").attr("checked", (localStorage["show_notification"] == "true"))
    $("#rss_url").val(localStorage["rss_url"])
    @update_advanced_info()


  update_advanced_info: =>
    info = "<br>
            Last Finished Writing: #{@last_finished_date().fromNow()}
            <br>
            Finished Today: #{if @finished_today() then 'Yes' else 'No'}
            <br>
            Time remaining today: #{@time_left_today()}
            <br>
            Current Streak: #{localStorage['current_streak']}"
    $(".advanced_info").html(info)


  time_left_today: =>
    moment.duration(moment().eod().diff(moment(), "seconds"), "seconds").humanize()


  #return moment().eod().diff(moment(), 'hours') + ' hours ' + moment().eod().diff(moment(), 'minutes') + ' minutes'
  last_finished_date: =>
    moment(new Date(localStorage["last_finished_date"]))


  finished_today: =>
    moment().eod().diff(moment(@last_finished_date(), "seconds")) < @a_day_of_seconds()


window.write_every_day_reminder = new WriteEveryDayReminder

