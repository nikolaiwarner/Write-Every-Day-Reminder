var write_every_day_reminder = {

  available: true,
  refresh_rate: 30 * 60 * 1000, // once every half hour
  default_rss_url: 'http://750words.com/api/rss/[your id]',

  refresh_timer: undefined,

  fetch_from_rss_url: function() {
    var self = this;
    if (localStorage['rss_url'] === undefined || localStorage['rss_url'] === this.default_rss_url) {
      localStorage['rss_url'] = this.default_rss_url;
    } else {    
      $.ajax({  
        url: localStorage['rss_url'],  
        success: function(data) { 
          self.available = true;
          self.rss_data_response(data);
        },
        error: function() {
          self.available = false;
          self.update_interface();
        }
      });
    }
  },


  rss_data_response: function(data) {
    var latest_item_description = $(data).find('rss channel item:first description').text();
    if (latest_item_description.indexOf("finished") !== -1) { // did you actually finish or just get started?

      // Streak
      var regex = new RegExp("is on a (.*) day writing streak", "g");
      var streak_array = regex.exec(latest_item_description);
//      console.log(latest_item_description, streak_array);
      if (streak_array) {
        localStorage['current_streak'] = parseInt(streak_array[1], 10);
      } else {
        localStorage['current_streak'] = "0";
      }


      var finished_date = new Date($(data).find('rss channel item:first pubDate').text());
      localStorage['last_finished_date'] = finished_date;

      if (this.finished_today()) { // did you finish within today?
        localStorage['progressed_today'] = 'true';
      } else {
        localStorage['progressed_today'] = 'false';
      } 
    } else {
      localStorage['progressed_today'] = 'false';
    }

    // Show notification
    if (localStorage['show_notification'] === 'true' && localStorage['progressed_today'] === 'false') {
      var notification = webkitNotifications.createHTMLNotification('notification.html');
      notification.show();
      setTimeout(function(){
        notification.cancel();
      }, '10000');
    }

    this.update_interface();
  },


  update_interface: function() {
    var self = this;

    if (this.available) {
      // Update Badge
      if (localStorage['show_badge'] === 'true') {
        chrome.browserAction.setBadgeText({text: localStorage['current_streak']});
      } else {
        chrome.browserAction.setBadgeText({text: ""});
      }

      // Update Progress
      if (localStorage['progressed_today'] === 'true') {
        chrome.browserAction.setIcon({path: "icon_success.png"});
        chrome.browserAction.setBadgeBackgroundColor({color:[0,255,0,255]});
      } else {
        chrome.browserAction.setIcon({path: "icon.png"});
        chrome.browserAction.setBadgeBackgroundColor({color:[255,0,0,255]});
      }
    } else {
      chrome.browserAction.setIcon({path: "icon_unavailable.png"});
      chrome.browserAction.setBadgeText({text: ""});
    }
  },


  schedule_refresh: function() {
    var self = this;
    if (this.refresh_timer) {
      clearInterval(this.refresh_timer);
    }
    this.refresh_timer = setInterval(function(){ self.update(); }, this.refresh_rate);
  },


  update: function() {
    // A simple scrape of the rss will do for now.
    // Perhaps someday there will be an official 750 words api.
    this.fetch_from_rss_url();
  },

  save_options: function() {
    localStorage["show_badge"] = $('#show_badge').is(':checked');
    localStorage["show_notification"] = $('#show_notification').is(':checked');
    localStorage["rss_url"] = $('#rss_url').val();

    // Update status to let user know options were saved.
    $("#status").html("Options Saved.");
    setTimeout(function() {
      $("#status").html("");
    }, 4000);
  },

  restore_options: function() {
    $('#show_badge').attr('checked', (localStorage["show_badge"] === "true"));
    $('#show_notification').attr('checked', (localStorage["show_notification"] === "true"));
    $('#rss_url').val(localStorage["rss_url"]);

    this.update_advanced_info();
  },

  update_advanced_info: function() {
    var info = "<br>";
    info = info + "Last Finished Writing: " + this.last_finished_date().fromNow();
    info = info + "<br>";
    info = info + "Finished Today: " + (this.finished_today() ? "Yes" : "No");
    info = info + "<br>";
    info = info + "Time remaining today: " + this.time_left_today();
    info = info + "<br>";
    info = info + "Current Streak: " + localStorage["current_streak"];

    $('.advanced_info').html(info);
  },

  time_left_today: function() {
    return moment.duration(moment().eod().diff(moment(), 'seconds'), 'seconds').humanize();
    //return moment().eod().diff(moment(), 'hours') + ' hours ' + moment().eod().diff(moment(), 'minutes') + ' minutes'
  },

  last_finished_date: function() {
    return moment(new Date(localStorage["last_finished_date"]));
  },

  a_day_of_seconds: function() {
    return 60 * 60 * 24;
  },

  finished_today: function() {
    return moment().eod().diff(moment(this.last_finished_date(), "seconds")) < this.a_day_of_seconds();
  }
};



// Events
document.addEventListener('DOMContentLoaded', function () {
  if ($('.options').length > 0) {
    // Options
    $('.save_button').click(write_every_day_reminder.save_options);
    write_every_day_reminder.restore_options();
    setInterval(function() { write_every_day_reminder.update_advanced_info() }, 10000);
  } else if ($('.notification').length > 0) {
    // Notification
    $('#time_left').html("Less than " + write_every_day_reminder.time_left_today() + " left to write today.");
    $(document).click(window.close);
  } else {
    // Background
    write_every_day_reminder.schedule_refresh();
    write_every_day_reminder.update();
    
    // listen_for_storage_updates
    window.addEventListener("storage", function(event){
      if (event.key === 'rss_url') {
        write_every_day_reminder.schedule_refresh();
        write_every_day_reminder.update();
      } else {
        write_every_day_reminder.update_interface();
      }
    }, false);
    
    // clickable icon
    chrome.browserAction.onClicked.addListener(function(tab) {
      if (write_every_day_reminder.available) {
        chrome.tabs.create({url: 'http://750words.com'});
      } else {
        chrome.tabs.create({url: 'options.html'});
      }
    });
  }
});