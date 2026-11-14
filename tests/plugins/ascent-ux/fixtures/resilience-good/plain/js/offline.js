// Shows the offline banner while the browser has no network.
const banner = document.getElementById('offline');
function update() { banner.hidden = navigator.onLine; }
window.addEventListener('offline', update);
window.addEventListener('online', update);
update();
