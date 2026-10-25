<h2>{name}</h2>
<img src={photo} alt={name} />
<label for="n">Name</label>
<input id="n" bind:value={name} />
<div role="button" tabindex="0" on:click={pick} on:keydown={pick}>Pick</div>
