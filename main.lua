function love.load()
  love.window.setTitle("Nelinha's World")

  love.window.setMode(1000, 768)
  wf = require 'libraries/windfield/windfield'
  anim8 = require 'libraries/anim8/anim8'

  sti = require 'libraries/Simple-Tiled-Implementation/sti'
  cameraFile = require 'libraries/hump/camera'

  cam = cameraFile()

  sprites = {}
  sprites.playerSheet = love.graphics.newImage('sprites/playerSheet.png')
  sprites.enemySheet = love.graphics.newImage('sprites/enemySheet.png')
  sprites.background = love.graphics.newImage('sprites/background.png')

  local grid = anim8.newGrid(
    614,
    564,
    sprites.playerSheet:getWidth(),
    sprites.playerSheet:getHeight()
  )

  local enemyGrid = anim8.newGrid(100, 79, sprites.enemySheet:getWidth(), sprites.enemySheet:getHeight())

  animations = {}
  animations.idle = anim8.newAnimation(grid('1-15', 1), 0.05)
  animations.jump = anim8.newAnimation(grid('1-7', 2), 0.05)
  animations.run = anim8.newAnimation(grid('1-15', 3), 0.05)
  animations.enemy = anim8.newAnimation(enemyGrid('1-2', 1), 0.03)

  world = wf.newWorld(0, 800, false)
  world:setQueryDebugDrawing(true)

  world:addCollisionClass('Player')
  world:addCollisionClass('Platform')
  world:addCollisionClass('Danger')

  require('player')
  require('enemy')
  require('libraries/show')

  dangerZone = world:newRectangleCollider(-500, 800, 5000, 50, { collision_class = 'Danger' })
  dangerZone:setType('static')

  platforms = {}

  flagX = 0
  flagY = 0

  saveData = {}
  saveData.currentLevel = "level1"

  -- Recover save from filesystem
  if love.filesystem.getInfo("data.lua") then
    local data = love.filesystem.load("data.lua")

    data()
  end

  sounds = {}
  sounds.jump = love.audio.newSource("sounds/jump.wav", "static")
  sounds.music = love.audio.newSource("sounds/music.mp3", "stream")
  sounds.music:setLooping(true)
  sounds.music:setVolume(0.4)

  sounds.music:play()

  loadMap(saveData.currentLevel)

  gameOver = false
end

function love.update(dt)
  world:update(dt)

  gameMap:update(dt)

  playerUpdate(dt)
  updateEnemies(dt)

  local px, py = player:getPosition()
  cam:lookAt(px, love.graphics.getHeight()/2)

  local colliders = world:queryCircleArea(flagX, flagY, 10, {'Player'})
  if #colliders > 0 then
    if saveData.currentLevel == "level1" then
      loadMap("level2")
    elseif saveData.currentLevel == "level2" then
      loadMap("level3")
    elseif saveData.currentLevel == "level3" then
      gameOver = true
    end
  end
end

function love.draw()
  love.graphics.draw(sprites.background, 0, 0)

  cam:attach()
    gameMap:drawLayer(gameMap.layers["Camada de Tiles 1"])

    drawPlayer()
    drawEnemies()

    -- world:draw()
  cam:detach()

  if gameOver then
    love.graphics.setFont(love.graphics.newFont(30))
    love.graphics.printf("Game Over!", 0, 50, love.graphics.getWidth(), "center")
  end
end

function love.keypressed(key)
  if key == 'up' or key == 'space' then
    if player.grounded then
      player:applyLinearImpulse(0, -4000)
      sounds.jump:play()
    end
  end
end

function loadMap(mapName)
  saveData.currentLevel = mapName
  love.filesystem.write("data.lua", table.show(saveData, "saveData"))

  destroyAll()
  player:setPosition(playerStartX, playerStartY)

  gameMap = sti("maps/".. mapName ..".lua")
  for i, obj in pairs(gameMap.layers["Platforms"].objects) do
    spawnPlatforms(obj.x, obj.y, obj.width, obj.height)
  end

  for i, obj in pairs(gameMap.layers["Enemies"].objects) do
    spawnEnemy(obj.x, obj.y)
  end

  for i, obj in pairs(gameMap.layers["Start"].objects) do
    playerStartX = obj.x
    playerStartY = obj.y
  end

  if gameMap.layers["NextLevel"] ~= nil then
    for i, obj in pairs(gameMap.layers["NextLevel"].objects) do
      flagX = obj.x
      flagY = obj.y
    end
  end
end

function destroyAll()
  local i = #platforms
  while i > -1 do
    if platforms[i] ~= nil then
      platforms[i]:destroy()
    end
    table.remove(platforms, i)
    i = i - 1
  end

  local i = #enemies
  while i > -1 do
    if enemies[i] ~= nil then
      enemies[i]:destroy()
    end
    table.remove(enemies, i)
    i = i - 1
  end
end

function spawnPlatforms(x, y, width, height)
  if width > 0 and height > 0 then
    platform = world:newRectangleCollider(x, y, width, height, { collision_class = 'Platform' })
    platform:setType('static')
    table.insert(platforms, platform)
  end
end