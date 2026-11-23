import 'dart:js_interop';
import 'package:web/web.dart' as web;

void printPage() {
  web.window.print();
}

void printInvoiceHtml(String htmlContent) {
  try {
    final blob = web.Blob([htmlContent.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
    final url = web.URL.createObjectURL(blob);
    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.style.position = 'fixed';
    iframe.style.right = '0';
    iframe.style.bottom = '0';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = '0';
    iframe.src = url;
    web.document.body?.appendChild(iframe);

    iframe.onload = ((web.Event e) {
      iframe.contentWindow?.focus();
      iframe.contentWindow?.print();
      web.window.setTimeout((() {
        iframe.remove();
        web.URL.revokeObjectURL(url);
      }).toJS, 3000.toJS);
    }).toJS;
  } catch (_) {
    web.window.print();
  }
}
