# FPGA Snake Game 


## Current Features

### Game Play
- Grid-based movement (14×10 grid)
- Wall collision detection
- Game over and restart by pressing any button
- Initial snake length: 5 segments

### Visual 
- 640×480 @ 60Hz
- Background Image: 320×240 background
- 3 different skins (20×20 pixels each)
- Game boundary with color 12'h684

### LCD Display
- 不知道為什麼不能用ㄟ system clk 應該都是100MHZ吧

### Control
  - BTN0: Up
  - BTN1: Down
  - BTN2: Left
  - BTN3: Right
- UART Control: Serial commands (WASD keys)
  - W/w: Up
  - S/s: Down
  - A/a: Left
  - D/d: Right

### Customization
- Switch between 3 snake textures
  - SW0: Skin 0 (default)
  - SW1: Skin 1
  - SW2: Skin 2
  (盡量一次推一個switch, 數字小的優先序高)

## File Structure

### Main Source Files

```
lab10.v                          # Main game module
├── VGA Rendering
├── Game Logic
├── LCD Display
└── Input Handling

Required Modules:
├── vga_sync.v                   # VGA timing generator
├── clk_divider.v                # Clock divider
├── LCD_module.v                 # LCD controller
├── debounce.v                   # Button debouncer
├── sram.v                       # Memory controller
└── uart.v                       # Serial communication

Memory Files:
├── background.mem               # 320×240 background
└── skin.mem                     # 3 snake skins 
