// The confirm page sends people back to the start: location.href = "nowhere.html" in a comment is ignored
document.getElementById('form').addEventListener('submit', () => {
  window.location = '/confirm.html';
});
