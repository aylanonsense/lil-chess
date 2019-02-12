-- Constants
local GAME_WIDTH = 200
local GAME_HEIGHT = 200
local RENDER_SCALE = 3
local TILE_WIDTH = 25
local TILE_HEIGHT = 20
local NUM_COLS = 8
local NUM_ROWS = 10

-- Game vars
local animTimer
local mouseCol
local mouseRow
local possibleMoves

-- Game objects
local selectedPiece
local pieces

-- Images
local chessPiecesImage

-- Sound effects
local selectSound
local deselectSound
local moveSound
local captureSound

-- Initializes the game
function love.load()
  -- Initialize game vars
  animTimer = 0.00

  -- Load images
  chessPiecesImage = loadImage('img/chess-pieces-2.png')

  -- Load sound effects
  selectSound = love.audio.newSource('sfx/select.wav', 'static')
  deselectSound = love.audio.newSource('sfx/deselect.wav', 'static')
  moveSound = love.audio.newSource('sfx/move.wav', 'static')
  captureSound = love.audio.newSource('sfx/capture.wav', 'static')

  -- Create the game objects
  pieces = {}
  createChessPiece('bishop', 2, 2, 3)
  createChessPiece('knight', 2, 4, 5)
  createChessPiece('rook', 2, 6, 4)
  createChessPiece('bishop', 1, 4, 9)
  createChessPiece('knight', 1, 5, 9)
  createChessPiece('rook', 1, 7, 8)
end

-- Updates the game state
function love.update(dt)
  -- Make the pieces bounce up and down
  animTimer = (animTimer + dt) % 1.00

  -- Figure out the currently highlighted tile
  local mouseX = love.mouse.getX() / RENDER_SCALE
  local mouseY = love.mouse.getY() / RENDER_SCALE
  mouseCol = math.floor(1 + mouseX / TILE_WIDTH)
  mouseRow = math.floor(1 + mouseY / TILE_HEIGHT)

  -- Sort pieces for drawing
  table.sort(pieces, function(a, b)
    return a.row < b.row
  end)
end

-- Renders the game
function love.draw()
  -- Set some drawing filters
  love.graphics.setDefaultFilter('nearest', 'nearest')
  love.graphics.scale(RENDER_SCALE, RENDER_SCALE)

  -- Clear the screen
  love.graphics.setColor(13 / 255, 17 / 255, 164 / 255, 1)
  love.graphics.rectangle('fill', 0, 0, GAME_WIDTH, GAME_HEIGHT)

  -- Draw checkered tiles
  love.graphics.setColor(3 / 255, 86 / 255, 222 / 255, 1)
  for col = 1, NUM_COLS do
    for row = 1, NUM_ROWS do
      if (col + row) % 2 == 0 then
        love.graphics.rectangle('fill', TILE_WIDTH * (col - 1), TILE_HEIGHT * (row - 1), TILE_WIDTH, TILE_HEIGHT)
      end
    end
  end

  -- Draw the shadows
  love.graphics.setColor(13 / 255, 17 / 255, 164 / 255, 1)
  for _, piece in ipairs(pieces) do
    if not piece.hasBeenCaptured then
      love.graphics.rectangle('fill', TILE_WIDTH * (piece.col - 1), TILE_HEIGHT * (piece.row - 1) + 5, TILE_WIDTH / 2, 10)
    end
  end

  -- Draw a highlight around the selected piece and all of its possible moves
  if selectedPiece then
    love.graphics.setColor(1, 1, 1, 1)
    highlightTile(selectedPiece.col, selectedPiece.row)
    for _, tile in ipairs(possibleMoves) do
      highlightTile(tile.col, tile.row)
    end
  end

  -- Draw a hightlight around the mouse
  love.graphics.setColor(1, 1, 1, 1)
  highlightTile(mouseCol, mouseRow)

  -- Draw the chess pieces
  for _, piece in ipairs(pieces) do
    local spriteNum
    if piece.type == 'knight' then
      spriteNum = 2
    elseif piece.type == 'rook' then
      spriteNum = 3
    elseif piece.type == 'bishop' then
      spriteNum = 4
    end
    if animTimer < 0.50 then
      spriteNum = spriteNum + 6
    end
    if piece.playerNum == 1 then
      love.graphics.setColor(1.00, 0.85, 0.10, 1)
    else
      love.graphics.setColor(1.00, 0.15, 0.50, 1)
    end
    if not piece.hasBeenCaptured then
      drawSprite(chessPiecesImage, spriteNum, 23, 40, false, TILE_WIDTH * (piece.col - 0.5) - 11, TILE_HEIGHT * (piece.row - 0.5) - 35)
    end
  end
end

-- CLick to select or move a chess piece
function love.mousepressed()
  if selectedPiece then
    if isPossibleMove(mouseCol, mouseRow) then
      -- Capture a piece
      local otherPiece = getChessPieceAtTile(mouseCol, mouseRow)
      if otherPiece then
        otherPiece.hasBeenCaptured = true
        love.audio.play(captureSound:clone())
      else
        love.audio.play(moveSound:clone())
      end
      -- Move the selected piece
      selectedPiece.col = mouseCol
      selectedPiece.row = mouseRow
    else
      love.audio.play(deselectSound:clone())
    end
    -- Deselect the selected piece
    selectedPiece = nil
    possibleMoves = nil
  else
    -- Select a piece
    selectedPiece = getChessPieceAtTile(mouseCol, mouseRow)
    if selectedPiece then
      possibleMoves = calculatePossibleMovies(selectedPiece)
      love.audio.play(selectSound:clone())
    end
  end
end

-- Calculates the possible moves for a piece
function calculatePossibleMovies(piece)
  local moves = {}
  -- The knight moves in L shapes
  if piece.type == 'knight' then
    -- Look left and right
    for dx = -1, 1, 2 do
      -- Up and down
      for dy = -1, 1, 2 do
        -- For each quadrant, look at the two possible L shapes
        for mult = 1, 2 do
          local col = piece.col + dx * mult
          local row = piece.row + dy * (3 - mult)
          local otherPiece = getChessPieceAtTile(col, row)
          -- It's an illegal move if it's out of bounds or if there's an allied piece there
          if isInBounds(col, row) and (not otherPiece or otherPiece.playerNum ~= piece.playerNum) then
            table.insert(moves, { col = col, row = row })
          end
        end
      end
    end
  -- The rook moves in straight lines
  elseif piece.type == 'rook' then
    -- Check every direction
    for dir = 1, 4 do
      for dist = 1, math.max(NUM_COLS, NUM_ROWS) do
        local col = piece.col
        local row = piece.row
        if dir == 1 then -- up
          row = row - dist
        elseif dir == 2 then -- left
          col = col - dist
        elseif dir == 3 then -- down
          row = row + dist
        elseif dir == 4 then -- right
          col = col + dist
        end
        -- Stop if we're out of bounds
        if not isInBounds(col, row) then
          break
        end
        local otherPiece = getChessPieceAtTile(col, row)
        if otherPiece then
          -- Can capture opposing pieces
          if otherPiece.playerNum ~= piece.playerNum then
            table.insert(moves, { col = col, row = row })
          end
          -- Can't move any further, though
          break
        else
          -- Can move so long as there aren't obstacles
          table.insert(moves, { col = col, row = row })
        end
      end
    end
  -- The bishop moves diagonally
  elseif piece.type == 'bishop' then
    -- Check every direction
    for dir = 1, 4 do
      for dist = 1, math.max(NUM_COLS, NUM_ROWS) do
        local col = piece.col
        local row = piece.row
        if dir == 1 then -- northwest
          col = col - dist
          row = row - dist
        elseif dir == 2 then -- northeast
          col = col + dist
          row = row - dist
        elseif dir == 3 then -- southwest
          col = col - dist
          row = row + dist
        elseif dir == 4 then -- southeast
          col = col + dist
          row = row + dist
        end
        -- Stop if we're out of bounds
        if not isInBounds(col, row) then
          break
        end
        local otherPiece = getChessPieceAtTile(col, row)
        if otherPiece then
          -- Can capture opposing pieces
          if otherPiece.playerNum ~= piece.playerNum then
            table.insert(moves, { col = col, row = row })
          end
          -- Can't move any further, though
          break
        else
          -- Can move so long as there aren't obstacles
          table.insert(moves, { col = col, row = row })
        end
      end
    end
  end
  return moves
end

-- Figures out if it's legal to move the selected piece to the given tile
function isPossibleMove(col, row)
  for _, tile in ipairs(possibleMoves) do
    if tile.col == col and tile.row == row then
      return true
    end
  end
end

-- Creates a new chess piece
function createChessPiece(type, playerNum, col, row)
  table.insert(pieces, {
    type = type,
    playerNum = playerNum,
    col = col,
    row = row,
    hasBeenCaptured = false
  })
end

-- Gets the chess piece at the given tile, if one is there
function getChessPieceAtTile(col, row)
  for _, piece in ipairs(pieces) do
    if piece.col == col and piece.row == row and not piece.hasBeenCaptured then
      return piece
    end
  end
end

-- Draws an outline around a tile
function highlightTile(col, row)
  love.graphics.rectangle('line', TILE_WIDTH * (col - 1), TILE_HEIGHT * (row - 1), TILE_WIDTH, TILE_HEIGHT)
end

-- Checks to see if a tile is in bounds
function isInBounds(col, row)
  return 1 <= col and col <= NUM_COLS and 1 <= row and row <= NUM_ROWS
end

-- Loads a pixelated image
function loadImage(filePath)
  local image = love.graphics.newImage(filePath)
  image:setFilter('nearest', 'nearest')
  return image
end

-- Draws a sprite from a sprite sheet image, spriteNum=1 is the upper-leftmost sprite
function drawSprite(image, spriteNum, spriteWidth, spriteHeight, flipHorizontally, x, y)
  local columns = math.floor(image:getWidth() / spriteWidth)
  local col = (spriteNum - 1) % columns
  local row = math.floor((spriteNum - 1) / columns)
  local quad = love.graphics.newQuad(spriteWidth * col, spriteHeight * row, spriteWidth, spriteHeight, image:getDimensions())
  love.graphics.draw(image, quad, x + (flipHorizontally and spriteWidth or 0), y, 0, flipHorizontally and -1 or 1, 1)
end
