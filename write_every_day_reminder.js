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
    var a_day_of_miliseconds = 60 * 60 * 24 * 1000;
    
    var latest_item_description = $(data).find('rss channel item:first description').text();
    if (latest_item_description.indexOf("finished") != -1) { // did you actually finish or just get started?
      
      
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
      
      var midnight = new Date(); 
      midnight.setDate(midnight.getDate() + 1);
      midnight.setHours(0); 
      midnight.setMinutes(0); 
      midnight.setSeconds(0);
      
      console.log(midnight.valueOf() - finished_date.valueOf() );
      
      if (midnight.valueOf() - finished_date.valueOf() < a_day_of_miliseconds) { // did you finish within today?
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
      }, '20000');
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

  init: function() {
    this.schedule_refresh();
    this.update();
  }
};