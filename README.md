# nalto-vault .OPEN SOURCE.

A comprehensive vault robbery system for FiveM QBCore framework. This script provides an intricate bank heist experience with multiple hacking stages, lootable trolleys, and drill spots.

## 🌟 Features

- Multi-stage vault hacking system
- Progressive security system with 5 different hack points
- Lootable money/gold trolleys with animations
- Drilling spots for additional rewards
- Police notification system
- Durability system for hacking devices
- Configurable police requirements
- Multiple minigames integration

## 📋 Dependencies

Required resources:
- [qb-core](https://github.com/qbcore-framework/qb-core)
- [qb-target](https://github.com/qbcore-framework/qb-target)
- [bd-minigames](https://github.com/sample/bd-minigames) - For PinCracker minigame
- [hacking](https://github.com/sample/hacking) - For hacking minigames
- [bl_ui](https://github.com/sample/bl_ui) - For Untangle minigame (optional)
- [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch) (optional) - For police alerts
- [vaUltMLO](https://github.com/uFLOKY/the-vault-bank) - MLO
## ⚙️ Configuration

The script includes extensive configuration options in `config.lua` and `client.lua` :
- Police requirements
- Hack difficulty settings
- Reward types and amounts
- Trolley positions and types
- Drilling spot locations

## 🎮 Minigames

The robbery features multiple types of hacking minigames:
1. PinCracker (First 3 stages)
2. Special hacking interface (Stages 4-5)
3. Drilling minigame for additional rewards

## 💎 Rewards

- Money trolleys: Loose notes
- Gold trolleys: Gold bars
- Drilling spots: Random rewards (Rolex, Cuban chains, loose notes)

## 🚓 Police Integration

- Configurable minimum police requirement
- Automated dispatch notifications
- Police can secure/close vault doors
- Cooldown system for alerts

## ⚡ Installation

1. Ensure all dependencies are installed
2. Copy the resource to your resources folder
3. Add to your `server.cfg` or add to `standalone folder` :
```cfg
ensure nalto-money
```

## 🔧 Usage

The vault robbery includes:
- 6 hackable security points
- Multiple lootable trolleys
- 6 drillable spots
- Requires specific items:
  - Trojan USB
  - Vault Laptop
  - Drill

## 🤝 Credits

thanks to https://github.com/uFLOKY/the-vault-bank for creating the sick mlo

Made for QBCore Framework


## ⚠️ Important Notes

- Ensure all dependencies are up to date
- Configure the `config.lua` to match your server's economy
- Test thoroughly before deploying to production
- Consider adding custom rewards to match your server's economy
