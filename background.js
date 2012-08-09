write_every_day_reminder.init();

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
