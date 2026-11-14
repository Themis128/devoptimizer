// AUTH-only probe: EHLO -> STARTTLS -> AUTH LOGIN -> QUIT. Never sends mail.
const fs=require('fs'),path=require('path'),tls=require('tls'),net=require('net');
const DIR='//wsl.localhost/Ubuntu-24.04/home/tbaltzakis/cu130-slim';
function envVal(k){const e=fs.readFileSync(path.join(DIR,'.env'),'utf8');const m=e.match(new RegExp('^'+k+'=(.+)$','m'));return m&&m[1].trim().replace(/^["']|["']$/g,'');}
const host=envVal('SMTP_RELAY_HOST')||'smtp.resend.com';
const port=parseInt(envVal('SMTP_RELAY_PORT')||envVal('SMTP_PORT')||'587',10);
const user=envVal('SMTP_USER'),pass=envVal('SMTP_PASSWORD');
const b64=s=>Buffer.from(s).toString('base64');
let buf='',i=0,sock,phase=0;
const steps=['EHLO monitor','STARTTLS','EHLO monitor','AUTH LOGIN',b64(user),b64(pass),'QUIT'];
function onData(d){buf+=d;if(!/(^|\r\n)\d{3} /.test(buf))return;const code=parseInt(buf.slice(0,3),10);const txt=buf;buf='';
 console.log('S:',txt.split('\r\n').filter(l=>l.trim()).slice(-1)[0].slice(0,100));
 if(code>=400){console.log('FAIL code',code);sock.destroy();process.exit(1);}
 if(i<steps.length){const cmd=steps[i++];console.log('C:',cmd.replace(/[A-Za-z0-9+/=]{20,}/g,'<b64>'));sock.write(cmd+'\r\n');}else{sock.end();process.exit(0);}}
console.log('probing',host,port,'user=',user);
sock=net.connect(port,host);
sock.on('data',d=>{buf+=d;if(!/(^|\r\n)\d{3} /.test(buf))return;const code=parseInt(buf.slice(0,3),10);const txt=buf;buf='';
 console.log('S:',txt.split('\r\n').filter(l=>l.trim()).slice(-1)[0].slice(0,100));
 if(code>=400){console.log('FAIL greeting',code);process.exit(1);}
 phase=1;sock.write('EHLO monitor\r\n');});
sock.on('error',e=>{console.log('ERR',e.message);process.exit(1);});
// after STARTTLS response upgrade
const origWrite=sock.write.bind(sock);
// simpler: intercept when we send STARTTLS — handled inside onData? Re-implement below.
