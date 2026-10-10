/* Shared theme wiring for index.html / help.html / faqs.html.
   localStorage key 'uiTheme' keeps the values 'dark' | 'light' (back-compat);
   the daisyUI data-theme attribute is mapped dark -> luxury, light -> fantasy. */
(function () {
  function dataTheme(ui) { return ui === 'light' ? 'fantasy' : 'luxury'; }
  function uiTheme() {
    try { return localStorage.getItem('uiTheme') === 'light' ? 'light' : 'dark'; } catch (e) { return 'dark'; }
  }
  function currentUi() {
    return document.documentElement.getAttribute('data-theme') === 'fantasy' ? 'light' : 'dark';
  }
  window.applyTheme = function (ui) {
    document.documentElement.setAttribute('data-theme', dataTheme(ui));
    var btn = document.getElementById('themeToggle');
    if (btn) btn.textContent = ui === 'dark' ? '☼' : '☾';
  };
  function bind() {
    var btn = document.getElementById('themeToggle');
    if (!btn || btn.dataset.themeBound) return;
    btn.dataset.themeBound = '1';
    applyTheme(currentUi());
    btn.addEventListener('click', function () {
      var next = currentUi() === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      try { localStorage.setItem('uiTheme', next); } catch (e) {}
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
