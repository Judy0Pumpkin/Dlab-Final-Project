# FPGA Snake Game 


## Current Features

### Game Play
- Grid-based movement (14×10 grid)
- Wall collision detection
- Game start / over / restart by pressing any button
- Initial snake length: 5 segments
- Generate food (almost) randomly
- Fixed obstacles (想要的話應該也可以隨機生，但應該要改LFSR不然會跟食物撞到，或是多設幾組固定的輪換就好)
- Grow longer when eat food
- Score system:
  - Initial with 5
  - Increase when eat food, decrease when hit wall / obstacles(1 per move)
  - Game over when score drops to 0 or snake_collision

### Visual 
- 640×480 @ 60Hz
- Background Image: 320×240 background
  - Now changes to color 12'h8a5 & 12'h9c6
- 3 different skins (20×20 pixels each)
- Game boundary with color 12'h684
- Red circle for food (20×20 pixels each)
- Brick for obstacles (20×20 pixels each)
- Text and num for score

### LCD Display
- 不知道為什麼不能用ㄟ system clk 應該都是100MHZ吧
- 不修了

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
├── uart.v                       # Serial communication
└── random_num.v                 # Generate new location of food with LFSR

Memory Files:
├── background.mem               # 320×240 background
├── skin.mem                     # 3 snake skins 
├── fruit.mem                    # food
├── score_text.mem               # "SCORE :"
├── score_num.mem                # number from 0 to 9
└── obstacle.mem                 # brick