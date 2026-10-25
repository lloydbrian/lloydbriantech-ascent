export function Widget({ label, src }) {
  return (
    <section>
      {/* <img src="ignored.png"> */}
      <h2>Widget</h2>
      <img src={src} alt={label} />
      <label htmlFor="qty">Quantity</label>
      <input id="qty" type="number" />
      <Button onClick={save}>Save</Button>
      <button onClick={save}>{label}</button>
      <div role="button" tabIndex={0} onClick={save} onKeyDown={save}>More</div>
      <a href="/help" className="link focus-visible:ring">Help</a>
    </section>
  );
}
