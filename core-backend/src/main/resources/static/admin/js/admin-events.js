/*
 * Sự kiện realtime của trang quản trị: EventSource('/admin/events') (SSE, chỉ ROLE_ADMIN).
 * - Mỗi sự kiện hiện một toast Bootstrap với thông điệp (chỉ có mã hóa đơn và số lượng, không dữ liệu cá nhân).
 * - Hóa đơn chờ duyệt / phản hồi OCR mới: tăng badge ở thanh bên; nếu đang mở đúng trang đó thì hiện thanh
 *   "Có dữ liệu mới – tải lại" thay cho badge.
 * - Mất kết nối (mạng, máy chủ khởi động lại, tab ngủ): EventSource tự kết nối lại sau vài giây (máy chủ gửi retry).
 *   Phiên đăng nhập hết hạn: máy chủ đóng luồng, lần kết nối lại bị chuyển tới trang đăng nhập và EventSource dừng hẳn.
 * Văn bản luôn được gán bằng textContent, không bao giờ bằng innerHTML.
 */
(function () {
    'use strict';

    var EVENTS_URL = '/admin/events';
    var EVENT_NAME = 'admin';
    var STORAGE_PREFIX = 'adminEvents.badge.';
    var TOAST_DELAY_MS = 6000;
    var MAX_BADGE = 99;
    var RELOAD_BAR_ID = 'adminEventsReloadBar';
    /** Loại sự kiện -> trang có badge ở thanh bên. */
    var PAGE_OF_TYPE = {
        RECEIPT_WAITING_REVIEW: '/admin/receipts',
        OCR_FEEDBACK_REPORTED: '/admin/ocr-feedbacks'
    };

    if (!window.EventSource) {
        return;
    }

    // sessionStorage có thể bị chặn (chế độ riêng tư, chính sách trình duyệt): khi đó badge chỉ sống trong trang hiện tại.
    var memoryCounts = {};

    function readCount(page) {
        try {
            var stored = window.sessionStorage.getItem(STORAGE_PREFIX + page);
            return stored ? (parseInt(stored, 10) || 0) : 0;
        } catch (e) {
            return memoryCounts[page] || 0;
        }
    }

    function writeCount(page, count) {
        memoryCounts[page] = count;
        try {
            window.sessionStorage.setItem(STORAGE_PREFIX + page, String(count));
        } catch (e) {
            // Bỏ qua: đã giữ trong bộ nhớ.
        }
    }

    function renderBadge(page) {
        var badge = document.querySelector('[data-admin-badge="' + page + '"]');
        if (!badge) {
            return;
        }
        var count = readCount(page);
        badge.textContent = count > MAX_BADGE ? MAX_BADGE + '+' : String(count);
        badge.classList.toggle('d-none', count === 0);
    }

    function currentPage() {
        return window.location.pathname.replace(/\/+$/, '');
    }

    function showToast(message) {
        var area = document.getElementById('adminToastArea');
        if (!area || !message) {
            return;
        }
        var toast = document.createElement('div');
        toast.className = 'toast align-items-center text-bg-primary border-0';
        toast.setAttribute('role', 'status');
        var row = document.createElement('div');
        row.className = 'd-flex';
        var body = document.createElement('div');
        body.className = 'toast-body';
        body.textContent = message;
        var close = document.createElement('button');
        close.type = 'button';
        close.className = 'btn-close btn-close-white me-2 m-auto';
        close.setAttribute('data-bs-dismiss', 'toast');
        close.setAttribute('aria-label', 'Đóng');
        row.appendChild(body);
        row.appendChild(close);
        toast.appendChild(row);
        area.appendChild(toast);
        toast.addEventListener('hidden.bs.toast', function () {
            toast.remove();
        });
        if (window.bootstrap && window.bootstrap.Toast) {
            window.bootstrap.Toast.getOrCreateInstance(toast, {delay: TOAST_DELAY_MS}).show();
        } else {
            window.setTimeout(function () { toast.remove(); }, TOAST_DELAY_MS);
        }
    }

    function showReloadBar() {
        if (document.getElementById(RELOAD_BAR_ID)) {
            return;
        }
        var main = document.querySelector('main.content');
        if (!main) {
            return;
        }
        var bar = document.createElement('div');
        bar.id = RELOAD_BAR_ID;
        bar.className = 'alert alert-info d-flex justify-content-between align-items-center';
        bar.setAttribute('role', 'status');
        var text = document.createElement('span');
        text.textContent = 'Có dữ liệu mới – tải lại để xem.';
        var reload = document.createElement('button');
        reload.type = 'button';
        reload.className = 'btn btn-sm btn-primary';
        reload.textContent = 'Tải lại';
        reload.addEventListener('click', function () {
            window.location.reload();
        });
        bar.appendChild(text);
        bar.appendChild(reload);
        var title = main.querySelector('.page-title');
        main.insertBefore(bar, title ? title.nextSibling : main.firstChild);
    }

    function onAdminEvent(event) {
        var data;
        try {
            data = JSON.parse(event.data);
        } catch (e) {
            return;
        }
        if (!data || typeof data.message !== 'string') {
            return;
        }
        showToast(data.message);
        var page = PAGE_OF_TYPE[data.type];
        if (!page) {
            return;
        }
        if (currentPage() === page) {
            showReloadBar();
        } else {
            writeCount(page, readCount(page) + 1);
            renderBadge(page);
        }
    }

    function start() {
        // Đang xem trang nào thì badge của trang đó coi như đã đọc.
        var here = currentPage();
        Object.keys(PAGE_OF_TYPE).forEach(function (type) {
            var page = PAGE_OF_TYPE[type];
            if (page === here) {
                writeCount(page, 0);
            }
            renderBadge(page);
        });
        var source = new EventSource(EVENTS_URL);
        source.addEventListener(EVENT_NAME, onAdminEvent);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start);
    } else {
        start();
    }
})();
