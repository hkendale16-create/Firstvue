(function () {
  var SUPABASE_URL = 'https://sdssshegqdwobjelxzkp.supabase.co';
  var SUPABASE_KEY =
    'sb_publishable_6unIQcDOjqw0seW5o8B8Gw_7YmpU5RT';

  function setMeta(name, content) {
    if (!content) return;
    var el =
      document.querySelector('meta[name="' + name + '"]') ||
      document.querySelector('meta[property="' + name + '"]');
    if (!el) {
      el = document.createElement('meta');
      if (name.indexOf('og:') === 0 || name.indexOf('twitter:') === 0) {
        el.setAttribute('property', name);
      } else {
        el.setAttribute('name', name);
      }
      document.head.appendChild(el);
    }
    el.setAttribute('content', content);
  }

  function applySeo(title, description, canonicalUrl) {
    if (title) {
      document.title = title;
      setMeta('og:title', title);
      setMeta('twitter:title', title);
    }
    if (description) {
      setMeta('description', description);
      setMeta('og:description', description);
      setMeta('twitter:description', description);
    }
    if (canonicalUrl) {
      var link = document.querySelector('link[rel="canonical"]');
      if (!link) {
        link = document.createElement('link');
        link.setAttribute('rel', 'canonical');
        document.head.appendChild(link);
      }
      link.setAttribute('href', canonicalUrl);
      setMeta('og:url', canonicalUrl);
    }
    setMeta('og:type', 'website');
  }

  function supabaseGet(path) {
    return fetch(SUPABASE_URL + '/rest/v1/' + path, {
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: 'Bearer ' + SUPABASE_KEY,
      },
    }).then(function (response) {
      if (!response.ok) throw new Error('fetch failed');
      return response.json();
    });
  }

  var params = new URLSearchParams(window.location.search);
  var profileId = params.get('profile');
  var postId = params.get('post');
  var origin = window.location.origin;

  if (postId) {
    supabaseGet(
      'community_news_posts?id=eq.' +
        encodeURIComponent(postId) +
        '&select=body,author_id&limit=1',
    )
      .then(function (rows) {
        var row = rows && rows[0];
        if (!row) return;
        var body = (row.body || '').trim();
        var snippet =
          body.length > 160 ? body.substring(0, 160) + '…' : body;
        return supabaseGet(
          'profiles?id=eq.' +
            encodeURIComponent(row.author_id) +
            '&select=display_name&limit=1',
        ).then(function (profiles) {
          var name =
            (profiles && profiles[0] && profiles[0].display_name) ||
            'FirstVue member';
          applySeo(
            name + ' on FirstVue',
            snippet || 'View this post on FirstVue.',
            origin + '/?post=' + encodeURIComponent(postId),
          );
        });
      })
      .catch(function () {
        applySeo(
          'Post on FirstVue',
          'View this post on FirstVue.',
          origin + '/?post=' + encodeURIComponent(postId),
        );
      });
    return;
  }

  if (profileId) {
    supabaseGet(
      'profiles?id=eq.' +
        encodeURIComponent(profileId) +
        '&select=display_name,username,bio&limit=1',
    )
      .then(function (rows) {
        var row = rows && rows[0];
        if (!row) return;
        var name = row.display_name || row.username || 'FirstVue member';
        var bio = (row.bio || '').trim();
        applySeo(
          name + ' on FirstVue',
          bio || 'View this member profile on FirstVue.',
          origin + '/?profile=' + encodeURIComponent(profileId),
        );
      })
      .catch(function () {
        applySeo(
          'Profile on FirstVue',
          'View this member profile on FirstVue.',
          origin + '/?profile=' + encodeURIComponent(profileId),
        );
      });
  }
})();
