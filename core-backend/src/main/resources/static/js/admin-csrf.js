// Trang quản trị dùng session nên mọi request đổi dữ liệu phải gửi kèm CSRF token (meta _csrf / _csrf_header của _layout.html).
// Nạp trong <head>, trước các script của từng trang: bọc fetch và XMLHttpRequest (jQuery.ajax dùng XHR, kể cả khi trang
// nạp lại jQuery sau đó) để tự thêm header vào mọi request khác GET/HEAD/OPTIONS, cùng origin.
(function () {
    'use strict';

    var SAFE_METHODS = ['GET', 'HEAD', 'OPTIONS', 'TRACE'];

    function meta(name) {
        var element = document.querySelector('meta[name="' + name + '"]');
        return element ? element.getAttribute('content') : null;
    }

    function needsToken(method, url) {
        if (SAFE_METHODS.indexOf(String(method || 'GET').toUpperCase()) !== -1) {
            return false;
        }
        try {
            return new URL(url, window.location.href).origin === window.location.origin;
        } catch (e) {
            return false;
        }
    }

    function tokenHeader() {
        var name = meta('_csrf_header');
        var value = meta('_csrf');
        return name && value ? { name: name, value: value } : null;
    }

    if (window.fetch) {
        var originalFetch = window.fetch;
        window.fetch = function (input, init) {
            var isRequest = typeof Request !== 'undefined' && input instanceof Request;
            var method = (init && init.method) || (isRequest ? input.method : 'GET');
            var url = isRequest ? input.url : String(input);
            var header = tokenHeader();
            if (header && needsToken(method, url)) {
                init = init || {};
                var headers = new Headers(init.headers || (isRequest ? input.headers : undefined));
                headers.set(header.name, header.value);
                init.headers = headers;
            }
            return originalFetch.call(this, input, init);
        };
    }

    var originalOpen = XMLHttpRequest.prototype.open;
    var originalSend = XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open = function (method, url) {
        this._csrfTarget = { method: method, url: url };
        return originalOpen.apply(this, arguments);
    };
    XMLHttpRequest.prototype.send = function () {
        var target = this._csrfTarget;
        var header = tokenHeader();
        if (header && target && needsToken(target.method, target.url)) {
            this.setRequestHeader(header.name, header.value);
        }
        return originalSend.apply(this, arguments);
    };
})();
