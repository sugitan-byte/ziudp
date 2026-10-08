# ZI-UDP Server Automated Installer (Hysteria 1 UDP)

⚡ **ZI-UDP Server** သည် Hysteria 1 protocol ကို အခြေခံထားသော High-Speed UDP Tunnel Server ဖြစ်ပြီး ISP များ၏ UDP throttling နှင့် blocking များကို ကျော်လွှားနိုင်ရန် **UDP Port Hopping (6000:19999)** နည်းပညာကို အသုံးပြုထားပါသည်။

ဤ Script သည် Ubuntu / Debian / CentOS Linux VPS ပေါ်တွင် ZI-UDP Server ကို 1-Click ဖြင့် အလိုအလျောက် တပ်ဆင်ပေးပြီး Ko Ko VPN / ZIVPN App တွင် ထည့်သွင်းအသုံးပြုနိုင်မည့် Client Configuration JSON ကို တခါတည်း ထုတ်ပေးပါသည်။

---

## 🚀 Quick Install (တစ်ချက်နှိပ် တပ်ဆင်နည်း)

သင်၏ Linux VPS (Ubuntu/Debian) Terminal တွင် အောက်ပါ command ကို Run လိုက်ပါ:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sugitan-byte/ziudp/main/install.sh)
```

> **မှတ်ချက်:** Root user ဖြင့် run ရန် လိုအပ်ပါသည်။ (`sudo -i` သို့မဟုတ် `root` ဖြင့် run ပါ)

---

## 🛠 Features (ပါဝင်သော စွမ်းဆောင်ရည်များ)

- ⚡ **Hysteria 1 Core & Brutal Engine:** မြန်ဆန်ပြီး Latency နည်းပါးသော Apernet Hysteria 1 Engine ကို အသုံးပြုထားပါသည်။
- 🚀 **Brutal Congestion Control (200+ Mbps):** ISP များ၏ Speed Throttling (Speed လျှော့ချခြင်း) ကို အပြည့်အဝ ကျော်လွှားပြီး Original Max Speed 200+ Mbps အပြည့်ရရှိစေရန် Brutal Rate Controller ဖြင့် ထိန်းချုပ်ထားပါသည်။
- 🔄 **UDP Port Hopping:** UDP Ports `6000:19999` range တစ်ခုလုံးကို internal port (5667) သို့ iptables ဖြင့် အလိုအလျောက် Redirect လုပ်ပေးထားပါသည်။
- 📶 **Anti-Throttling MTU Safety:** 4G/5G Cellular ကွန်ရက်များတွင် Packet drop မဖြစ်စေရန် Safe MTU Discovery Optimization ထည့်သွင်းထားပါသည်။
- 🔒 **Obfuscation & TLS Security:** TLS Certificate အလိုအလျောက် ထုတ်ပေးပြီး `obfs` password ဖြင့် traffic ကို ဖုံးကွယ်ထားပါသည်။
- 📱 **ZIVPN & Ko Ko VPN Ready:** App တွင် တိုက်ရိုက် Paste လုပ်ရုံဖြင့် ချိတ်ဆက်နိုင်မည့် Client JSON Format ကို ထုတ်ပေးပါသည်။
- 🎛 **Easy Management Menu:** Install ပြီးပါက Terminal တွင် `ziudp` ဟု ရိုက်လိုက်ရုံဖြင့် User အသစ်ထည့်ခြင်း၊ Speed Limit (200/300 Mbps) ပြောင်းခြင်း၊ Status စစ်ဆေးခြင်းတို့ကို ပြုလုပ်နိုင်ပါသည်။
- 🚀 **BBR & 64MB Buffer Tuning:** Linux Kernel တွင် 64MB Network Buffer Window များကို အမြင့်ဆုံး အနေအထားသို့ အလိုအလျောက် Optimize လုပ်ပေးပါသည်။

---

## 🎛 Server စီမံခန့်ခွဲနည်း (Management Menu)

Install လုပ်ပြီးပါက မည်သည့်အချိန်မဆို Terminal တွင် အောက်ပါ Command ကို ရိုက်ပါ:

```bash
ziudp
```

အောက်ပါအတိုင်း Menu ပေါ်လာမည် ဖြစ်ပါသည်:
```text
==========================================
       ZI-UDP Server Management Menu       
==========================================
 1) Show Client Configuration (ZIVPN JSON)
 2) Add New User Password
 3) Remove User Password
 4) Change Obfuscation (obfs) Password
 5) Tune / Change Speed Limits (Brutal 200/300 Mbps)
 6) Check Server Status
 7) View Live Logs
 8) Restart Server
 9) Reconfigure iptables Port Hopping
 10) Uninstall ZI-UDP Server
 0) Exit
------------------------------------------
```

---

## 🛡 Firewall Port ဖွင့်ရန် (အရေးကြီးသည်)

Cloud VPS (AWS, GCP, Oracle, DigitalOcean, Linode, Vultr စသည်) သုံးနေပါက VPS Firewall / Security Group တွင် UDP Port Range ကို Allow လုပ်ပေးရန် လိုအပ်ပါသည်:

* **Protocol:** `UDP`
* **Port Range:** `6000-19999` (နှင့် Internal Port `5667`)

Ubuntu UFW သုံးနေပါက:
```bash
ufw allow 6000:19999/udp
ufw allow 5667/udp
ufw reload
```

---

## 📱 App / Admin Panel တွင် ထည့်သွင်းနည်း

Script ပြီးဆုံးသည့်အခါ ထွက်လာသော Client JSON ကို ကူးယူပြီး အောက်ပါအတိုင်း ထည့်သွင်းနိုင်ပါသည်:

### ၁။ Ko Ko VPN / ZIVPN Client JSON Format:
```json
{
  "Country": "My Server 🇸🇬",
  "Region": "SG",
  "Server": "udp3.zivpn.com",
  "ServerIP": "YOUR_SERVER_IP",
  "Protocol": "Hysteria1 (UDP)",
  "Obfs": "YOUR_OBFS_KEY",
  "Auth": "YOUR_AUTH_KEY",
  "Ports": [
    "6000-9500",
    "9501-13000",
    "13001-16500",
    "16501-19999"
  ],
  "UpMbps": "50",
  "DownMbps": "200",
  "Socks5Listen": "127.0.0.1:1080-1083",
  "Insecure": true,
  "RecvWindowConn": 1048576,
  "RecvWindow": 393216,
  "Engine": "libuz.so"
}
```

### ၂။ Admin Panel `NetworkPayload` တွင် ထည့်သွင်းနည်း:
Admin Panel ၏ `NetworkPayload` အကွက်ထဲသို့ Script က ထုတ်ပေးသော Single-line JSON ကို ထည့်ပေးလိုက်ရုံပါပဲ။

---

## ⚙️ System Requirements

- **OS:** Ubuntu 20.04/22.04/24.04, Debian 10/11/12, CentOS 7/8/9, AlmaLinux
- **Architecture:** x86_64 (amd64) သို့မဟုတ် aarch64 (arm64)
- **RAM:** အနည်းဆုံး 512MB RAM
- **Root Access:** `sudo` သို့မဟုတ် `root` 권한

---

## 📄 License
MIT License
