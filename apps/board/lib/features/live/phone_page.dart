/// The page students open on their phones: one self-contained HTML file (no CDN, no fonts to
/// fetch), so it works on a classroom Wi-Fi or hotspot with no internet. It asks for the room
/// code and roll number, then polls the board for the open question every 1.5 s.
const phonePage = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>Zynetix class quiz</title>
<style>
:root{--bg:#0f2a1d;--card:#173a29;--fg:#f4f7f2;--muted:#b9c9bd;--accent:#ffb300;--ok:#1b8a3a;--bad:#c62828}
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
body{margin:0;background:var(--bg);color:var(--fg);font:18px/1.4 system-ui,-apple-system,"Segoe UI",Roboto,"Noto Sans Kannada",sans-serif}
main{max-width:560px;margin:0 auto;padding:16px}
h1{font-size:22px;margin:4px 0 12px;color:var(--accent)}
label{display:block;margin:14px 0 6px;color:var(--muted)}
input{width:100%;font-size:32px;padding:12px 14px;border-radius:14px;border:2px solid #3d6b52;background:#0b1f15;color:var(--fg);text-align:center;letter-spacing:4px}
button{width:100%;font-size:24px;font-weight:700;padding:16px;margin-top:12px;border:0;border-radius:16px;background:var(--accent);color:#000}
button:disabled{opacity:.45}
.opt{display:flex;align-items:center;gap:14px;text-align:left;background:var(--card);color:var(--fg);border:3px solid transparent;font-weight:600}
.opt b{flex:none;width:44px;height:44px;border-radius:50%;background:#ffffff22;display:flex;align-items:center;justify-content:center;font-size:24px}
.opt.sel{border-color:var(--accent);background:#5a4a12}
.opt.right{background:var(--ok)}
.opt.wrong{background:var(--bad)}
.stem{font-size:20px;background:var(--card);padding:14px;border-radius:14px;white-space:pre-wrap}
.msg{text-align:center;font-size:22px;padding:18px;border-radius:16px;background:var(--card);margin-top:14px}
.ok{background:var(--ok)}.bad{background:var(--bad)}
.err{color:#ff8a80;min-height:24px;margin-top:8px}
.top{display:flex;justify-content:space-between;color:var(--muted);font-size:16px}
.link{background:none;color:var(--muted);font-size:16px;font-weight:400;padding:8px;width:auto;margin:0}
.top{align-items:center}
.opt:disabled{opacity:.7}.opt.sel:disabled,.opt.right:disabled,.opt.wrong:disabled{opacity:1}
</style>
</head>
<body>
<main>
  <div id="join" hidden>
    <h1 id="t-title"></h1>
    <label for="room" id="t-room"></label>
    <input id="room" inputmode="numeric" maxlength="4" autocomplete="off">
    <label for="roll" id="t-roll"></label>
    <input id="roll" inputmode="numeric" maxlength="3" autocomplete="off">
    <button id="go"></button>
    <div class="err" id="joinErr"></div>
  </div>
  <div id="play" hidden>
    <div class="top"><span id="who"></span><button class="link" id="change"></button></div>
    <div id="body"></div>
    <div class="err" id="playErr"></div>
  </div>
</main>
<script>
(function(){
var T={
 en:{title:'Class quiz',room:'Room code (on the board)',roll:'Your roll number',go:'Join',change:'Change roll',rollNo:'Roll No.',
  wait:'Wait for the teacher to send a question',send:'Send answer',sent:'Answer sent. Wait for the teacher to reveal.',
  right:'Right!',wrong:'Wrong.',none:'You did not answer this one.',answer:'Answer',pickAll:'Tap every correct option, then send.',
  number:'Type a number',errroom:'Wrong room code. Check the board.',errroll:'That roll number is not in this class.',
  errtaken:'That roll number has joined on another phone. Ask the teacher.',errclosed:'Answers are closed for this question.',
  erralready:'You have already answered.',errinvalid:'Check your answer.',errtooMany:'Too many tries. Ask the teacher.',errnet:'Cannot reach the board. Are you on the class Wi-Fi?'},
 kn:{title:'ತರಗತಿ ರಸಪ್ರಶ್ನೆ',room:'ಕೊಠಡಿ ಕೋಡ್ (ಬೋರ್ಡ್ ಮೇಲೆ)',roll:'ನಿಮ್ಮ ರೋಲ್ ಸಂಖ್ಯೆ',go:'ಸೇರಿ',change:'ರೋಲ್ ಬದಲಿಸಿ',rollNo:'ರೋಲ್ ಸಂ.',
  wait:'ಶಿಕ್ಷಕರು ಪ್ರಶ್ನೆ ಕಳುಹಿಸುವವರೆಗೆ ಕಾಯಿರಿ',send:'ಉತ್ತರ ಕಳುಹಿಸಿ',sent:'ಉತ್ತರ ಕಳುಹಿಸಲಾಗಿದೆ. ಶಿಕ್ಷಕರು ತೋರಿಸುವವರೆಗೆ ಕಾಯಿರಿ.',
  right:'ಸರಿ!',wrong:'ತಪ್ಪು.',none:'ನೀವು ಇದಕ್ಕೆ ಉತ್ತರಿಸಲಿಲ್ಲ.',answer:'ಉತ್ತರ',pickAll:'ಸರಿಯಾದ ಎಲ್ಲವನ್ನೂ ಒತ್ತಿ, ನಂತರ ಕಳುಹಿಸಿ.',
  number:'ಸಂಖ್ಯೆ ಟೈಪ್ ಮಾಡಿ',errroom:'ತಪ್ಪು ಕೊಠಡಿ ಕೋಡ್. ಬೋರ್ಡ್ ನೋಡಿ.',errroll:'ಈ ರೋಲ್ ಸಂಖ್ಯೆ ಈ ತರಗತಿಯಲ್ಲಿಲ್ಲ.',
  errtaken:'ಈ ರೋಲ್ ಸಂಖ್ಯೆ ಬೇರೆ ಫೋನಿನಲ್ಲಿ ಸೇರಿದೆ. ಶಿಕ್ಷಕರನ್ನು ಕೇಳಿ.',errclosed:'ಈ ಪ್ರಶ್ನೆಗೆ ಉತ್ತರಗಳು ಮುಚ್ಚಿವೆ.',
  erralready:'ನೀವು ಈಗಾಗಲೇ ಉತ್ತರಿಸಿದ್ದೀರಿ.',errinvalid:'ನಿಮ್ಮ ಉತ್ತರ ಪರಿಶೀಲಿಸಿ.',errtooMany:'ಹಲವು ಪ್ರಯತ್ನಗಳು. ಶಿಕ್ಷಕರನ್ನು ಕೇಳಿ.',errnet:'ಬೋರ್ಡ್ ಸಿಗುತ್ತಿಲ್ಲ. ತರಗತಿಯ ವೈ-ಫೈನಲ್ಲಿದ್ದೀರಾ?'}};
var lang='en',token=null,state=null,picked=[],shownKey='',busy=false;
function $(id){return document.getElementById(id)}
function t(k){return (T[lang]||T.en)[k]||T.en[k]||k}
function store(k,v){try{if(v===undefined)return localStorage.getItem(k);if(v===null)localStorage.removeItem(k);else localStorage.setItem(k,v)}catch(e){return null}}
function esc(s){return String(s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function api(method,path,body){
 return fetch(path,{method:method,headers:body?{'Content-Type':'application/json'}:{},body:body?JSON.stringify(body):undefined,cache:'no-store'})
  .then(function(r){return r.json().then(function(j){j.status=r.status;return j})});
}
function labels(){
 document.documentElement.lang=lang;
 $('t-title').textContent=t('title');$('t-room').textContent=t('room');$('t-roll').textContent=t('roll');$('go').textContent=t('go');$('change').textContent=t('change');
}
function showJoin(){ $('join').hidden=false;$('play').hidden=true;labels(); }
function join(){
 var room=$('room').value.trim(),roll=$('roll').value.trim();$('joinErr').textContent='';
 $('go').disabled=true;
 api('POST','/join',{room:room,roll:roll,token:token}).then(function(j){
  $('go').disabled=false;
  if(j.error){$('joinErr').textContent=t('err'+j.error);return}
  token=j.token;store('zx-token',token);store('zx-room',room);shownKey='';poll();
 }).catch(function(){$('go').disabled=false;$('joinErr').textContent=t('errnet')});
}
function send(body){
 if(busy)return;busy=true;$('playErr').textContent='';
 body.token=token;body.seq=state.seq;
 api('POST','/answer',body).then(function(j){busy=false;if(j.error)$('playErr').textContent=t('err'+j.error);shownKey='';poll()})
  .catch(function(){busy=false;$('playErr').textContent=t('errnet')});
}
function render(s){
 var key=JSON.stringify([s.phase,s.seq,s.mine,s.correct,lang,picked]);
 if(key===shownKey)return;shownKey=key;
 $('join').hidden=true;$('play').hidden=false;labels();
 $('who').textContent=t('rollNo')+' '+s.roll;
 var b=$('body'),h='';
 if(s.phase==='waiting'||!s.format){b.innerHTML='<div class="msg">'+esc(t('wait'))+'</div>';return}
 h+='<p class="stem">'+esc(s.stem)+'</p>';
 var mine=s.mine,rev=s.phase==='revealed',ans=String(s.answer||'');
 if(s.format==='numeric'){
  if(mine||rev){h+='<div class="msg">'+(mine?esc(mine.value):'—')+'</div>'}
  else{h+='<input id="num" inputmode="decimal" placeholder="'+esc(t('number'))+'" autocomplete="off"><button id="send">'+esc(t('send'))+'</button>'}
 }else{
  var chosen=mine?(mine.choices||(mine.choice!=null?[mine.choice]:[])):picked;
  for(var i=0;i<s.options.length;i++){
   var L='ABCD'[i],cls='opt';
   if(chosen.indexOf(i)>=0)cls+=' sel';
   if(rev){if(ans.indexOf(L)>=0)cls+=' right';else if(chosen.indexOf(i)>=0)cls+=' wrong'}
   h+='<button class="'+cls+'" data-i="'+i+'"'+(mine||rev?' disabled':'')+'><b>'+L+'</b><span>'+esc(s.options[i])+'</span></button>';
  }
  if(s.format==='multi'&&!mine&&!rev){h+='<p>'+esc(t('pickAll'))+'</p><button id="send"'+(picked.length?'':' disabled')+'>'+esc(t('send'))+'</button>'}
 }
 if(rev){
  if(s.correct===true)h+='<div class="msg ok">'+esc(t('right'))+'</div>';
  else if(s.correct===false)h+='<div class="msg bad">'+esc(t('wrong'))+' '+esc(t('answer'))+': '+esc(ans)+'</div>';
  else h+='<div class="msg">'+esc(t('none'))+' '+esc(t('answer'))+': '+esc(ans)+'</div>';
 }else if(mine){h+='<div class="msg">'+esc(t('sent'))+'</div>'}
 b.innerHTML=h;
 var opts=b.querySelectorAll('.opt');
 for(var k=0;k<opts.length;k++)opts[k].onclick=function(){
  var i=+this.getAttribute('data-i');
  if(s.format==='multi'){var p=picked.indexOf(i);if(p>=0)picked.splice(p,1);else picked.push(i);render(s)}
  else send({choice:i});
 };
 var sb=$('send');
 if(sb)sb.onclick=function(){
  if(s.format==='numeric'){var v=parseFloat(($('num').value||'').replace('−','-').replace(',','.'));if(isNaN(v)){$('playErr').textContent=t('errinvalid');return}send({value:v})}
  else send({choices:picked.slice().sort()});
 };
}
var lastSeq=-1;
function poll(){
 if(!token){showJoin();return}
 api('GET','/state?token='+encodeURIComponent(token)).then(function(s){
  if(s.lang)lang=s.lang;
  if(s.error){token=null;store('zx-token',null);showJoin();return}
  $('playErr').textContent=$('playErr').textContent===t('errnet')?'':$('playErr').textContent;
  if(s.seq!==lastSeq){picked=[];lastSeq=s.seq;$('playErr').textContent=''}
  state=s;render(s);
 }).catch(function(){$('playErr').textContent=t('errnet')});
}
$('go').onclick=join;
$('roll').onkeydown=function(e){if(e.key==='Enter')join()};
$('change').onclick=function(){$('room').value=store('zx-room')||'';$('roll').value='';showJoin()};
token=store('zx-token');
var qs=new URLSearchParams(location.search);
$('room').value=qs.get('room')||store('zx-room')||'';
labels();
if(token)poll();else showJoin();
setInterval(function(){if(token&&!$('play').hidden)poll()},1500);
})();
</script>
</body>
</html>
''';
