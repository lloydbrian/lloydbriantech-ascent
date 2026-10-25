// A single-page-app view: HTML lives in template literals.
const greeting = `hello ${name}`;            // not HTML: ignored
export function renderZone(zone) {
  return `
    <section aria-labelledby="zone-title">
      <h2 id="zone-title">${zone.name}</h2>
      <label for="zone-size">Size</label>
      <input id="zone-size" type="number" value="${zone.size}">
      <img src="${zone.photo}" alt="${zone.name}">
      <button type="button" class="save">${t('save')}</button>
      <h4>Notes</h4>
    </section>`;
}
// Delegated listeners: the element a click listener finds with closest() must be
// keyboard-reachable too (C19).
export function renderPicker(id) {
  return `
    <div class="pick" role="button" tabindex="0" data-pick="${id}">Pick</div>`;
}
document.body.addEventListener('click', e => { const el = e.target.closest('[data-pick]'); if (el) pick(el); });
document.body.addEventListener('keydown', e => { if (e.key === 'Enter') { const el = e.target.closest('[data-pick]'); if (el) pick(el); } });
