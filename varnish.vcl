vcl 4.0;
#import directors; 
# Default backend definition. Set this to point to your content server.
backend django1 {
    .host = "10.0.0.145";
    .port = "1443";
}

#backend django2 {
#    .host = "10.0.0.243";
#    .port = "1443";
#}

#sub vcl_init {
#    new bar = directors.round_robin();
#    bar.add_backend(django1);
#    bar.add_backend(django2);
# }

sub vcl_recv {
    # Happens before we check if we have this in cache already.
    #
    # Typically you clean up the request here, removing cookies you don't need,
    # rewriting the request, etc.
    
    # send all traffic to the bar director:
    if (req.method == "POST") {
        return (pass);
    }

    if (req.url ~ "^/legacylive/(.*)$") {
        return (pass);
    }
#    set req.backend_hint = bar.backend();
    return (hash);
}

sub vcl_backend_response {
    # Happens after we have read the response headers from the backend.
    #
    # Here you clean the response headers, removing silly Set-Cookie headers
    # and other mistakes your backend does.

    set beresp.ttl = 1h;

    if (bereq.url ~ "^/release/(.*)$") {
        set beresp.ttl = 12h;
    }

    if (bereq.url ~ "^(/|/\?_pjax=%23pjax-container)$") {
        set beresp.ttl = 10m;
    }

    if (bereq.url ~ "^/download(/|/\?_pjax=%23pjax-container)$") {
        set beresp.ttl = 30d;
    }

    if (bereq.url ~ "^/legacylive/(.*)$") {
        set beresp.ttl = 0s;
    }
}

sub vcl_deliver {
    # Happens when we have all the pieces we need, and are about to send the
    # response to the client.
    #
    # You can do accounting or modifying the final object here.
    set resp.http.X-Age = resp.http.Age;
    unset resp.http.Age;
    set resp.http.Expires = "3600";

    if (obj.hits > 0) {
            set resp.http.X-Cache = "HIT";                           #命中則返回HIT
    } else {
            set resp.http.X-Cache = "MISS";                         #未命中則返回MISS
    }

    unset resp.http.Cache-Control;

    if (req.url ~ "^/release(/|/\?_pjax=%23pjax-container)$") {
        set resp.http.Expires = "43200";
    }

    if (req.url ~ "^(/|/\?_pjax=%23pjax-container)$") {
        set resp.http.Expires = "300";
    }


    if (req.url ~ "^/download(/|/\?_pjax=%23pjax-container)$") {
        set resp.http.Expires = "2592000";
    }

    if (req.url ~ "^/legacylive/(.*)$") {
        unset resp.http.Expires;
    }

}

sub vcl_hash {
      hash_data(req.url);
      return (lookup);
}