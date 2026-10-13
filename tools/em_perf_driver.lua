-- Frame-time probe: boot Emerald, stand still on Route 101, and report the
-- real frame interval with and without the mod's 2.5D pipeline. No battle,
-- no screenshots, no menu input -- just the renderer.
--   EM_FRAMES=<n>  frames to sample (default 240)
--   EM_PHASE=<s>   label for the log line
return function(game)
 local U=dofile('tests/drivers/util.lua')
 local frames=tonumber(os.getenv('EM_FRAMES') or 240)
 local phase=os.getenv('EM_PHASE') or 'overworld'
 love.window.setMode(1280,720,{resizable=true})
 game:_handleBootAction({action='new_game',name='MAY',gender=1,
   start={map='EM_ROUTE101',8,10,x=8,y=10,facing='down'}})
 U.wait(120)
 local sum,max,min,n=0,0,1e9,0
 local marks={}
 for t=1,frames do
  U.wait(1)
  local d=love.timer.getDelta()
  n=n+1;sum=sum+d
  if d>max then max=d end
  if d<min then min=d end
  if t%60==0 then marks[#marks+1]=string.format('%d:%.1f',t,d*1000) end
 end
 print(string.format('[PERF] %s frames=%d mean=%.1fms (%.1f fps) min=%.1f max=%.1f | %s',
   phase,n,sum/n*1000,n/sum,min*1000,max*1000,table.concat(marks,' ')))
 love.event.quit()
end
