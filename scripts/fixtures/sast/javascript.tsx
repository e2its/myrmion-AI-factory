// META-ONLY fixture for security/sast/javascript.yml (EVOL-074), the TypeScript / JSX forms.
import { DomSanitizer } from '@angular/platform-browser';

export function Comment({ body }: { body: string }) {
  // ruleid: javascript-raw-html
  const raw = <p dangerouslySetInnerHTML={{ __html: body }} />;
  // ok: javascript-raw-html
  const text = <p>{body}</p>;
  return <div>{raw}{text}</div>;
}

export class View {
  constructor(private sanitizer: DomSanitizer) {}
  render(html: string) {
    // ruleid: javascript-raw-html
    return this.sanitizer.bypassSecurityTrustHtml(html);
  }
  url(u: string) {
    // ok: javascript-raw-html
    return this.sanitizer.sanitize(1, u);
  }
}
