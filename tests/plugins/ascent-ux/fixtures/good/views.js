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
