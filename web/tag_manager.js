(() => {
  const containerId = document
    .querySelector('meta[name="google-tag-manager"]')
    ?.content.trim();
  if (!containerId || !/^GTM-[A-Z0-9]+$/.test(containerId)) return;

  const location = window.location;
  const appPath = new URL(document.baseURI).pathname;
  const relativePath = location.pathname.slice(appPath.length);
  if (/^admin(?:\/|$)/i.test(relativePath)) return;

  const query = new URLSearchParams(location.search);
  const fragment = new URLSearchParams(location.hash.slice(1));
  const authParameters = ['code', 'access_token', 'refresh_token', 'error_description'];
  if (authParameters.some((key) => query.has(key) || fragment.has(key))) return;

  window.dataLayer = window.dataLayer || [];
  window.dataLayer.push({ 'gtm.start': Date.now(), event: 'gtm.js' });

  const script = document.createElement('script');
  script.async = true;
  script.src = 'https://www.googletagmanager.com/gtm.js?id=' + containerId;
  document.head.appendChild(script);
})();
