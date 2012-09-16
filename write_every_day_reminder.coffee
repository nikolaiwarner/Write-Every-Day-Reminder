class WriteEveryDayReminder
  constructor: (options={}) ->
    @version = '2.0.0'
    @available = true
    @refresh_rate = options.refresh_rate || 30 * 60 * 1000 # default, once every half hour
    @default_rss_url = options.default_rss_url || "http://750words.com/api/rss/[your id]"
    @a_day_of_seconds = 86400
    @refresh_timer = undefined
    @notification = undefined

    # Initialize Chrome Events
    document.addEventListener "DOMContentLoaded", =>
      if $(".options").length > 0 # Init for Options Page
        $(".save_button").click => @save_options()
        @restore_options()
        # Update the advanced info every 10 seconds
        #setInterval (=> @update_advanced_info() ), 10000

      else if $(".notification").length > 0 # Init for Notification Page
        message = "<b>Time remaining: #{@time_left_today()}</b>
                   <br>
                   Last finished writing: #{@last_finished_date().fromNow()}
                  "
        $(".time_left").html(message)
        $(document).click window.close

      else # Init for Background Page
        @schedule_refresh()
        @update()

        # Listen for local storage updates
        window.addEventListener "storage", ((event) =>
          if event.key == "rss_url"
            @schedule_refresh()
            @update()
          else
            @update_interface()
        ), false

        # Clickable icon
        chrome.browserAction.onClicked.addListener (tab) =>
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

    finished_date = new Date($(data).find("rss channel item:first pubDate").text())
    localStorage["last_finished_date"] = finished_date

    if @finished_today() # did you finish within today?
      localStorage["progressed_today"] = "true"
    else
      localStorage["progressed_today"] = "false"

    # Streak
    if localStorage["progressed_today"] == "true" || @finished_yesterday()
      streak_array = undefined
      if latest_item_description.indexOf("finished") != -1 # did you actually finish or just get started?
        regex = new RegExp('img title="(.*) day streak"', "g")
        streak_array = regex.exec(latest_item_description)

      if streak_array
        localStorage["current_streak"] = parseInt(streak_array[1], 10)
      else
        localStorage["current_streak"] = ""
    else
      localStorage["current_streak"] = "0"


    # Show notification
    if localStorage["show_notification"] == "true" && localStorage["progressed_today"] == "false"
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
    info = "<strong>Advanced Info:</strong>
            <br>
            Last finished writing: #{@last_finished_date().fromNow()}
            <br>
            Finished yesterday: #{if @finished_yesterday() then 'Yes' else 'No'}
            <br>
            Finished today: #{if @finished_today() then 'Yes' else 'No'}
            <br>
            Time remaining today: #{@time_left_today()}
            <br>
            Current streak: #{localStorage['current_streak']}"
    $(".advanced_info").html(info)


  time_left_today: =>
    moment.duration(moment().eod().diff(moment(), "seconds"), "seconds").humanize()


  last_finished_date: =>
    moment(new Date(localStorage["last_finished_date"]))


  finished_today: =>
    # As in: (midnight today - last_finished_date ) < a_day_of_seconds
    moment().eod().diff(moment(@last_finished_date()), "seconds") < @a_day_of_seconds

  finished_yesterday: =>
    # As in: (midnight today - last_finished_date ) < a_day_of_seconds
    moment().eod().diff(moment(@last_finished_date()), "seconds") < (@a_day_of_seconds * 2)

window.write_every_day_reminder = new WriteEveryDayReminder

