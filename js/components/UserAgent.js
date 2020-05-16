/* vim:set ts=2 sts=2 sw=2 ft=javascript:*/
export default function(args, then, tokenStore) {
  let body;
  if (args.data) {
    body = (args.jsonRequest) ? JSON.stringify(args.data) : new URLSearchParams(args.data);
  }

  const ReloadMessage = "invalid session, please re-login.";

  return fetch(args.url, {
    method: "POST",
    cache: "no-cache",
    body: body,
    headers: {
      "X-Requested-With": "XMLHttpRequest",
      "Content-Type": args.jsonRequest ?
        "application/json; charset=utf-8" : "application/x-www-form-urlencoded",
    },
  })
    .then(function(response) {
      // 認証エラー
      if (response.status === 401) {
        tokenStore.commit("logout");
        const message = response.headers.get("WWW-Authenticate") ?
          'Incorrect username or password.' : ReloadMessage;
        throw new Error(message);
      }
      if (response.ok) {
        tokenStore.commit("login");
        return response;
      }
      throw new Error('Network Error');
    })
    .then(res => res.json())
    .then(then)
    .catch(error => {
      alert(error);

      if (error.message === ReloadMessage) {
        location.reload();
      }
    })
}
// TODO JSONを解いた後の then は外で定義するとエラー処理などすっきりする
