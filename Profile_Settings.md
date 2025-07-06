# AI Worker Avatars - Appearance Customization Legend

## 🎭 Basic Character Info

### **Gender**
```lua
gender = "male"    -- Male character
gender = "female"  -- Female character
```

### **Skin Tone** (1-6)
```lua
skinTone = 1  -- Very Light
skinTone = 2  -- Light  
skinTone = 3  -- Medium Light
skinTone = 4  -- Medium
skinTone = 5  -- Medium Dark
skinTone = 6  -- Dark
```

### **Body Type** (1-3)
```lua
bodyType = 1  -- Slim
bodyType = 2  -- Normal
bodyType = 3  -- Stocky
```

## 💇 Hair & Face

### **Hair Style** (1-12)
```lua
hairStyle = 1   -- Short
hairStyle = 2   -- Medium
hairStyle = 3   -- Long
hairStyle = 4   -- Curly Short
hairStyle = 5   -- Curly Long
hairStyle = 6   -- Buzz Cut
hairStyle = 7   -- Crew Cut
hairStyle = 8   -- Pompadour
hairStyle = 9   -- Slicked Back
hairStyle = 10  -- Messy
hairStyle = 11  -- Spiky
hairStyle = 12  -- Bald
```

### **Hair Color** (1-8)
```lua
hairColor = 1  -- Black
hairColor = 2  -- Dark Brown
hairColor = 3  -- Brown
hairColor = 4  -- Light Brown
hairColor = 5  -- Blonde
hairColor = 6  -- Red
hairColor = 7  -- Auburn
hairColor = 8  -- Gray
```

### **Face Shape** (1-6)
```lua
faceShape = 1  -- Face Shape 1
faceShape = 2  -- Face Shape 2
faceShape = 3  -- Face Shape 3
faceShape = 4  -- Face Shape 4
faceShape = 5  -- Face Shape 5
faceShape = 6  -- Face Shape 6
```

### **Eye Color** (1-4)
```lua
eyeColor = 1  -- Brown
eyeColor = 2  -- Blue
eyeColor = 3  -- Green
eyeColor = 4  -- Hazel
```

### **Facial Hair** (0-8) - Usually Male Only
```lua
facialHair = 0  -- None (clean shaven)
facialHair = 1  -- Mustache
facialHair = 2  -- Goatee
facialHair = 3  -- Full Beard
facialHair = 4  -- Stubble
facialHair = 5  -- Soul Patch
facialHair = 6  -- Handlebar Mustache
facialHair = 7  -- Chinstrap
facialHair = 8  -- Mutton Chops
```

## 🧢 Clothing

### **Hat Type** (0-6)
```lua
hatType = 0  -- No Hat
hatType = 1  -- Baseball Cap
hatType = 2  -- Beanie
hatType = 3  -- Cowboy Hat
hatType = 4  -- Trucker Hat
hatType = 5  -- Bucket Hat
hatType = 6  -- Work Hard Hat
```

### **Hat Color** (1-8) - When wearing a hat
```lua
hatColor = 1  -- Black
hatColor = 2  -- Blue
hatColor = 3  -- Red
hatColor = 4  -- Green
hatColor = 5  -- Brown
hatColor = 6  -- Gray
hatColor = 7  -- White
hatColor = 8  -- Yellow
```

### **Shirt Type** (1-8)
```lua
shirtType = 1  -- T-Shirt
shirtType = 2  -- Flannel
shirtType = 3  -- Work Shirt
shirtType = 4  -- Polo
shirtType = 5  -- Tank Top
shirtType = 6  -- Hoodie
shirtType = 7  -- Jacket
shirtType = 8  -- Vest
```

### **Shirt Color** (1-12)
```lua
shirtColor = 1   -- White
shirtColor = 2   -- Black
shirtColor = 3   -- Blue
shirtColor = 4   -- Red
shirtColor = 5   -- Green
shirtColor = 6   -- Yellow
shirtColor = 7   -- Gray
shirtColor = 8   -- Brown
shirtColor = 9   -- Orange
shirtColor = 10  -- Purple
shirtColor = 11  -- Pink
shirtColor = 12  -- Navy
```

### **Pants Type** (1-4)
```lua
pantsType = 1  -- Jeans
pantsType = 2  -- Work Pants
pantsType = 3  -- Overalls
pantsType = 4  -- Shorts
```

### **Pants Color** (1-8)
```lua
pantsColor = 1  -- Blue
pantsColor = 2  -- Black
pantsColor = 3  -- Brown
pantsColor = 4  -- Khaki
pantsColor = 5  -- Gray
pantsColor = 6  -- Green
pantsColor = 7  -- White
pantsColor = 8  -- Dark Blue
```

### **Boots Type** (1-4)
```lua
bootsType = 1  -- Work Boots
bootsType = 2  -- Sneakers
bootsType = 3  -- Hiking Boots
bootsType = 4  -- Rubber Boots
```

### **Boots Color** (1-6)
```lua
bootsColor = 1  -- Brown
bootsColor = 2  -- Black
bootsColor = 3  -- Tan
bootsColor = 4  -- Gray
bootsColor = 5  -- Green
bootsColor = 6  -- Yellow
```

## 🧤 Accessories

### **Gloves** (true/false)
```lua
gloves = true   -- Wearing work gloves
gloves = false  -- No gloves
```

### **Glove Color** (1-4) - When wearing gloves
```lua
gloveColor = 1  -- Brown
gloveColor = 2  -- Black
gloveColor = 3  -- Yellow
gloveColor = 4  -- Orange
```

### **Sunglasses** (true/false)
```lua
sunglasses = true   -- Wearing sunglasses
sunglasses = false  -- No sunglasses
```

### **Sunglasses Type** (1-3) - When wearing sunglasses
```lua
sunglassesType = 1  -- Aviator
sunglassesType = 2  -- Wayframe
sunglassesType = 3  -- Sport
```

## 🎭 Personality & Voice

### **Personality**
```lua
personality = "professional"  -- Serious, focused
personality = "casual"        -- Relaxed, friendly
personality = "energetic"     -- Enthusiastic, quick
personality = "calm"          -- Steady, patient
```

### **Voice Type** (1-6)
```lua
voiceType = 1  -- Voice Type 1
voiceType = 2  -- Voice Type 2
voiceType = 3  -- Voice Type 3
voiceType = 4  -- Voice Type 4
voiceType = 5  -- Voice Type 5
voiceType = 6  -- Voice Type 6
```

### **Accent**
```lua
accent = "neutral"   -- Standard accent
accent = "southern"  -- Southern drawl
accent = "midwest"   -- Midwestern accent
accent = "urban"     -- City accent
```

---

## 📝 Complete Character Example

```lua
{
    name = "Ranch Boss Jake",
    skills = {fieldWork = 90, transport = 85, precision = 80, speed = 75, efficiency = 88},
    appearance = {
        -- Basic Info
        gender = "male",
        skinTone = 2,        -- Light skin
        bodyType = 2,        -- Normal build
        faceShape = 3,       -- Face shape 3
        
        -- Hair & Face
        hairStyle = 3,       -- Long hair
        hairColor = 2,       -- Dark brown
        eyeColor = 2,        -- Blue eyes
        facialHair = 3,      -- Full beard
        
        -- Clothing
        hatType = 3,         -- Cowboy hat
        hatColor = 5,        -- Brown hat
        shirtType = 2,       -- Flannel shirt
        shirtColor = 4,      -- Red flannel
        pantsType = 1,       -- Jeans
        pantsColor = 1,      -- Blue jeans
        bootsType = 1,       -- Work boots
        bootsColor = 1,      -- Brown boots
        
        -- Accessories
        gloves = true,       -- Work gloves
        gloveColor = 1,      -- Brown gloves
        sunglasses = false,  -- No sunglasses
        
        -- Personality
        personality = "professional",
        voiceType = 3,
        accent = "neutral"
    }
}
```

## 🎬 YouTube Character Ideas

### **Ranch Foreman**
- Male, cowboy hat, beard, flannel, work boots, professional personality

### **Field Specialist** 
- Female, baseball cap, ponytail, work shirt, sunglasses, energetic personality

### **Equipment Expert**
- Female, no hat, short hair, polo shirt, work gloves, professional personality

### **Transport Driver**
- Male, trucker hat, t-shirt, jeans, casual personality

### **Ranch Hand**
- Male/Female, beanie, hoodie, work pants, energetic personality

---

*Use this legend to create authentic characters that match your YouTube ranch story!*