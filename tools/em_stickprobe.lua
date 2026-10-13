-- What does the running build see on the right stick, and does anything
-- else hold a camera key down?
return function(game)
 local U=dofile('tests/drivers/util.lua')
 U.wait(60)
 local names={'rightx','righty','leftx','lefty'}
 for _,n in ipairs(names) do
  local ok,list=pcall(love.joystick.getJoysticks)
  local out={}
  for i,js in ipairs(list or {}) do
   out[#out+1]=string.format('%d:%s:%s',i,tostring(js:isGamepad()),
     tostring(js:isGamepad() and js:getGamepadAxis(n) or 'n/a'))
  end
  print(string.format('[STICK] %s joysticks=%d %s',n,#(list or {}),table.concat(out,' ')))
 end
 local keys={'[',']','w','a','s','d'}
 local down={}
 for _,k in ipairs(keys) do if love.keyboard.isDown(k) then down[#down+1]=k end end
 print('[STICK] keys down: '..(#down>0 and table.concat(down,',') or '(none)'))
 love.event.quit()
end
