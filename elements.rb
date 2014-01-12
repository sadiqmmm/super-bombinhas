require './game_object'

############################### classes abstratas ##############################

class FloatingItem < GameObject
	def initialize x, y, w, h, img, img_gap = nil, sprite_cols = nil, sprite_rows = nil, indices = nil, interval = nil
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
		if img_gap
			@active_bounds = Rectangle.new x + img_gap.x, y - img_gap.y, @img[0].width, @img[0].height
		else
			@active_bounds = Rectangle.new x, y, @img[0].width, @img[0].height
		end
		@state = 3
		@counter = 0
		@indices = indices
		@interval = interval
	end
	
	def update section
		if section.bomb.collide? self
			yield
			@dead = true
		end
		@counter += 1
		if @counter == 10
			if @state == 0 or @state == 1; @y -= 1
			else; @y += 1; end
			@state += 1
			@state = 0 if @state == 4
			@counter = 0
		end
		animate @indices, @interval if @indices
	end
end

class TwoStateObject < GameObject
	def initialize x, y, w, h, img, img_gap, sprite_cols, sprite_rows,
		change_interval, anim_interval, change_anim_interval, s1_indices, s2_indices, s1_s2_indices, s2_s1_indices, s2_first = false
		super x, y, w, h, img, img_gap, sprite_cols, sprite_rows
		
		@timer = 0
		@changing = false
		@change_interval = change_interval
		@anim_interval = anim_interval
		@change_anim_interval = change_anim_interval
		@s1_indices = s1_indices
		@s2_indices = s2_indices
		@s1_s2_indices = s1_s2_indices
		@s2_s1_indices = s2_s1_indices
		@state2 = s2_first
		set_animation s2_indices[0] if s2_first
	end
	
	def update section
		@timer += 1
		if @timer == @change_interval
			@state2 = (not @state2)
			if @state2
				s1_to_s2 section
				set_animation @s1_s2_indices[0]
			else
				s2_to_s1 section
				set_animation @s2_s1_indices[0]
			end
			@changing = true
			@timer = 0
		end
		
		if @changing
			if @state2
				animate @s1_s2_indices, @change_anim_interval
				if @img_index == @s1_s2_indices[-1]
					set_animation @s1_s2_indices[-2]
					@changing = false
				end
			else
				animate @s2_s1_indices, @change_anim_interval
				if @img_index == @s2_s1_indices[-1]
					set_animation @s2_s1_indices[-2]
					@changing = false
				end
			end
		elsif @state2
			animate @s2_indices, @anim_interval if @anim_interval > 0
		else
			animate @s1_indices, @anim_interval if @anim_interval > 0
		end
	end
end

################################################################################

class FireRock < FloatingItem
	def initialize x, y, args
		super x + 6, y + 7, 20, 20, :sprite_FireRock, Vector.new(-2, -17), 4, 1, [0, 1, 2, 3], 5
	end
	
	def update section
		super section do
			G.player.score += 10
		end
	end
end

class Bombie < GameObject
	def initialize x, y, args
		super x, y, 32, 32, :sprite_Bombie, Vector.new(1, -2), 6, 1
		@msg_id = "msg#{args.to_i}".to_sym
		@balloon = Res.img :fx_Balloon1
		@facing_right = false
		@active = false
		@speaking = false
		@interval = 8
		
		@active_bounds = Rectangle.new x, y, 32, 32
	end
	
	def update section
		if section.bomb.collide? self
			if not @facing_right and section.bomb.bounds.x > @x + @w / 2
				@facing_right = true
				@indices = [3, 4, 5]
				set_animation 3
			elsif @facing_right and section.bomb.bounds.x < @x - @w / 2
				@facing_right = false
				@indices = [0, 1, 2]
				set_animation 0
			end
			if KB.key_pressed? Gosu::KbUp
				@speaking = (not @speaking)
				if @speaking
					if @facing_right; @indices = [3, 4, 5]
					else; @indices = [0, 1, 2]; end
					@active = false
				else
					if @facing_right; set_animation 3
					else; set_animation 0; end
				end
			end
			@active = (not @speaking)
		else
			@active = false
			@speaking = false
			if @facing_right; set_animation 3
			else; set_animation 0; end
		end
		
		animate @indices, @interval if @speaking
	end
	
	def draw map
		super map
		@balloon.draw @x - map.cam.x, @y - map.cam.y - 32, 0 if @active
		if @speaking
			G.window.draw_quad 5, 495, 0x80abcdef,
			                   795, 495, 0x80abcdef,
			                   795, 595, 0x80abcdef,
			                   5, 595, 0x80abcdef, 0
			G.font.draw Res.text(@msg_id), 10, 500, 0, 1, 1, 0xff000000
		end
	end
end

class Life < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Life, Vector.new(-3, -3), 8, 1,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
		@index = index
	end
	
	def update section
		super section do
			section.take_item @index, :Life, true, false
		end
	end
end

class Key < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Key, Vector.new(-3, -3)
		@index = index
	end
	
	def update section
		super section do
			section.take_item @index, :Key, true, true
		end
	end
end

class Door < GameObject
	def initialize x, y, args
		super x + 15, y + 63, 2, 1, :sprite_Door, Vector.new(-15, -63), 5, 1
		@id = args.to_i
		@locked = args.split(',').length == 2
		@open = false
		@active_bounds = Rectangle.new x, y, 32, 64
		@lock = Res.img(:sprite_Lock) if @locked
	end
	
	def update section
		collide = section.bomb.collide? self
		if @locked and collide
			section.locked_door = self
		end
		if not @locked and not @opening and collide
			if KB.key_pressed? Gosu::KbUp
				set_animation 1
				@opening = true
			end
		end
		if @opening
			animate [1, 2, 3, 4, 0], 5
			if @img_index == 0
				section.warp = @id
				@opening = false
			end
		end
	end
	
	def unlock
		@locked = false
		@lock = nil
	end
	
	def draw map
		super map
		@lock.draw(@x + 4 - map.cam.x, @y - 38 - map.cam.y, 0) if @lock
	end
end

class GunPowder < GameObject
	def initialize x, y, args, index
		super x + 3, y + 19, 26, 13, :sprite_GunPowder, Vector.new(-2, -2)
		@life = 10
		@counter = 0
		
		@active_bounds = Rectangle.new x + 1, y + 17, 30, 15
	end
	
	def update section
		if @active
			@counter += 1
			if @counter == 60
				@life -= 1
				if @life == 0
					section.bomb.explode
					@dead = true
				end
				@counter = 0
			end
		elsif section.bomb.collide? self
			@active = true
		end
	end
	
	def draw map
		if @active
			G.font.draw_rel Res.text(:count_down), 400, 200, 0, 0.5, 0.5, 1, 1, 0xff000000 if @life > 6
			G.font.draw_rel @life.to_s, 400, 220, 0, 0.5, 0.5, 1, 1, 0xff000000
		else
			super map
		end
	end
end

class Crack < GameObject
	def initialize x, y, args
		super x + 32, y, 32, 32, :sprite_Crack
		@active_bounds = Rectangle.new x + 32, y, 32, 32
	end
	
	def update section
		if section.bomb.explode? self
			i = (@x / C::TileSize).floor
			j = (@y / C::TileSize).floor
			section.on_tiles do |t|
				t[i][j].wall = -1
				t[i][j].pass = -1
			end
			@dead = true
		end
	end
end

class Elevator < GameObject
	def initialize x, y, args, obstacles
		a = args.split(':')
		type = a[0].to_i
		case type
			when 1 then w = 32; cols = nil; rows = nil
			when 2 then w = 64; cols = 4; rows = 1
		end
		super x, y, w, 1, "sprite_Elevator#{type}", Vector.new(0, 0), cols, rows
		@passable = true
		
		@speed_m = a[1].to_i
		@moving = false
		@point = 0
		@points = []
		min_x = x; min_y = y
		max_x = x; max_y = y
		ps = a[2..-1]
		ps.each do |p|
			coords = p.split ','
			p_x = coords[0].to_i * C::TileSize; p_y = coords[1].to_i * C::TileSize
			
			min_x = p_x if p_x < min_x
			min_y = p_y if p_y < min_y
			max_x = p_x if p_x > max_x
			max_y = p_y if p_y > max_y
			
			@points << [p_x, p_y]
		end
		@points << [x, y]
		@active_bounds = Rectangle.new min_x, min_y, (max_x - min_x + w), (max_y - min_y + @img[0].height)
		
		obstacles << self
	end
	
	def move_to x, y, obst
		if not @moving
			x_dist = x - @x; y_dist = y - @y
			freq = @speed_m / Math.sqrt(x_dist * x_dist + y_dist * y_dist)
			@speed.x = x_dist * freq
			@speed.y = y_dist * freq
			@moving = true
		end
		x_aim = @x + @speed.x; y_aim = @y + @speed.y
		passengers = []
		obst.each do |o|
			if @x + @w > o.x && o.x + o.w > @x
				foot = o.y + o.h
				if foot.round(6) == @y.round(6) || @speed.y < 0 && foot < @y && foot > y_aim
					passengers << o
				end
			end
		end
		
		if @speed.x > 0 && x_aim >= x || @speed.x < 0 && x_aim <= x
			passengers.each do |p| p.x += x - @x end
			@x = x; @speed.x = 0
		else
			passengers.each do |p| p.x += @speed.x end
			@x = x_aim
		end
		if @speed.y > 0 && y_aim >= y || @speed.y < 0 && y_aim <= y
			@y = y; @speed.y = 0
		else; @y = y_aim; end
		passengers.each do |p| p.y = @y - p.h end
		@moving = false if @speed.x == 0 && @speed.y == 0
	end
	
	def cycle obst
		move_to @points[@point][0], @points[@point][1], obst
		if not @moving
			if @point == @points.length - 1; @point = 0
			else; @point += 1; end
		end
	end
	
	def update section
		obst = [section.bomb] #verificar...
		cycle obst
	end
end

class SaveBombie < GameObject
	def initialize x, y, args
		super x - 16, y, 64, 32, :sprite_Bombie2, Vector.new(-16, -26), 4, 2
		@id = args.to_i
		@active_bounds = Rectangle.new x - 32, y - 26, 96, 58
		@saved = args.split(',').length == 2
		@indices = [1, 2, 3]
		set_animation 1 if @saved
	end
	
	def update section
		if not @saved and section.bomb.collide? self
			section.save_check_point @id, self
			@saved = true
		end
		
		if @saved
			animate @indices, 8
		end
	end
end

class Pin < TwoStateObject
	def initialize x, y, args, obstacles
		super x, y, 32, 32, :sprite_Pin, Vector.new(0, 0), 5, 1,
			60, 0, 3, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4], (not args.nil?)
		
		if args
			obstacles << Block.new(x, y, 32, 32, true)
		end
		
		@active_bounds = Rectangle.new x, y, 32, 32
	end
	
	def s1_to_s2 section
		section.on_obstacles do |o|
			o << Block.new(@x, @y, @w, @h, true)
		end
	end
	
	def s2_to_s1 section
		section.on_obstacles do |o|
			o.each do |b|
				if b.x == @x and b.y == @y
					o.delete b
					break
				end
			end
		end
	end
end

class Spikes < TwoStateObject
	def initialize x, y, args, obstacles
		super x, y, 32, 32, :sprite_Spikes, Vector.new(0, 0), 5, 1,
			120, 0, 2, [0], [4], [1, 2, 3, 4, 0], [3, 2, 1, 0, 4]
		
		@active_bounds = Rectangle.new x, y, 32, 33
	end
	
	def s1_to_s2 section
		section.on_obstacles do |o|
			o << Block.new(@x, @y + 30, @w, @h, false)
		end
	end
	
	def s2_to_s1 section
		section.on_obstacles do |o|
			o.each do |b|
				if b.x == @x and b.y == @y + 30
					o.delete b
					break
				end
			end
		end
	end
	
	def update section
		super section
		
		if section.bomb.collide? self and @state2
			G.player.die
		end
	end
end

class Attack1 < FloatingItem
	def initialize x, y, args, index
		super x + 3, y + 3, 26, 26, :sprite_Attack1, Vector.new(-3, -3), 8, 1,
			[0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7], 6
	end
	
	def update section
		super section do
			section.take_item -1, :Attack1, false, true
		end
	end
end

class MovingWall < GameObject
	def initialize x, y, args
		
	end
end

class Ball < GameObject
	def initialize x, y, args
		
	end
end

class BallReceptor < GameObject
	def initialize x, y, args
		
	end
end

class Spec < GameObject
	def initialize x, y, args, index
		
	end
end

class HideTile
	def initialize i, j, group, tiles, num
		@state = 0
		@alpha = 0xff
		@color = 0xffffffff
		
		@group = group
		@points = []
		check_tile i, j, tiles, 4
		
		@img = Res.imgs "sprite_ForeWall#{num}".to_sym, 5, 1
	end
	
	def check_tile i, j, tiles, dir
		return -1 if tiles[i].nil? or tiles[i][j].nil?
		return tiles[i][j].wall if tiles[i][j].hide < 0
		return 0 if tiles[i][j].hide == @group
		
		tiles[i][j].hide = @group
		t = 0; r = 0; b = 0; l = 0
		t = check_tile i, j-1, tiles, 0 if dir != 2
		r = check_tile i+1, j, tiles, 1 if dir != 3
		b = check_tile i, j+1, tiles, 2 if dir != 0
		l = check_tile i-1, j, tiles, 3 if dir != 1
		if t < 0 and r >= 0 and b >= 0 and l >= 0; img = 1
		elsif t >= 0 and r < 0 and b >= 0 and l >= 0; img = 2
		elsif t >= 0 and r >= 0 and b < 0 and l >= 0; img = 3
		elsif t >= 0 and r >= 0 and b >= 0 and l < 0; img = 4
		else; img = 0; end
		
		@points << {x: i * C::TileSize, y: j * C::TileSize, img: img}
		0
	end
	
	def update section
		will_show = false
		@points.each do |p|
			rect = Rectangle.new p[:x], p[:y], C::TileSize, C::TileSize
			if section.bomb.bounds.intersects rect
				will_show = true
				break
			end
		end
		if will_show; show
		else; hide; end
	end
	
	def show
		if @state != 2
			@alpha -= 17
			if @alpha == 51
				@state = 2
			else
				@state = 1
			end
			@color = 0x00ffffff | (@alpha << 24)
		end
	end
	
	def hide
		if @state != 0
			@alpha += 17
			if @alpha == 0xff
				@state = 0
			else
				@state = 1
			end
			@color = 0x00ffffff | (@alpha << 24)
		end
	end
	
	def is_visible map
		true
	end
	
	def draw map
		@points.each do |p|
			@img[p[:img]].draw p[:x] - map.cam.x, p[:y] - map.cam.y, 0, 1, 1, @color
		end
	end
end

