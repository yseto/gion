/* vim:set ts=2 sts=2 sw=2:*/
export default function(args, then) {
  const contentType = args.jsonRequest ? "application/json; charset=utf-8" : "application/x-www-form-urlencoded";
  let body;
  if (args.data) {
    body = (args.jsonRequest) ? JSON.stringify(args.data) : new URLSearchParams(args.data);
  }
  return fetch(args.url, {
      method: "POST",
      cache: "no-cache",
      credentials: "same-origin", 
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.getElementsByName('csrf-token')[0].content,
        'Cache-Control': 'no-cache',
        "Content-Type": contentType,
      },
      body: body,
  })
  .then(res => res.json())
  .then(then)
}
// TODO JSONを解いた後の then は外で定義するとエラー処理などすっきりする
