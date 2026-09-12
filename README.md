# chem-dorm

Chemistry-themed room tower defense for macOS. Godot 4.7.2 Standard + GDScript.
1 player + 5 ally bots vs 1 AI invader. Design lock: `DESIGN.md`.

## Local

```bash
cd /Users/a0000/Developer
git clone git@github.com:9947447-alt/chem-dorm.git
cd chem-dorm
```

Open the folder in Godot 4.7.2 (Standard, not .NET). First playable slice is a grid floor + claim-room loop only.

## 怎么玩

开游戏：终端 `godot --path .`，或 Godot 编辑器打开本目录后按 F5。

移动：W/A/S/D，方向键也可以。

占房：走到房间里的起步矿格子上，自动占房。一房只能被一人占。

选格：左键点任意一格（走廊、空地、建筑、门都会出菜单）。点菜单项才建造或升级并扣费。点菜单外或按 Esc 关闭，关闭不扣费。不能做的项是灰的，后面写原因。

矿：点自己房间空格，菜单里选矿种。矿建成后不能升级。

厂：点自己房间空格，菜单里选化工厂。再点这座厂，菜单里选升级。

炮：点自己房间空格，菜单里选硅酸炮台。再点这座炮，菜单里选升级。碳酸 V 时菜单出现换线 A / 换线 B。

门：点门格，菜单里选升级舱门。

起步矿：点起步格，菜单里选升级起步矿。

跳字：格子上「金币 +N」是起步矿或产金钱矿刚入账；「原料 +N」是化工厂刚入账。约 0.8 秒后消失。

门血条：画在每扇舱门格子上方。掉血变短，破门后是空条。

赢：炮台把入侵者 HP 打到 0。

输：自己房间的起步矿被拆光。

没有：暂停键、数字键建造、右键、空格。
