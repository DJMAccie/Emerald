-- Interior stairs from the native art
return {
 -- whole flights, matched on all their cells so no unrelated tile is borrowed
 -- (Pokemon Center: up to 2F at the west wall, and its top on 2F going down)
 flights={
  {pair='building__pokemon_center',rows={{0x280,0x281},{0x288,0x289},{0x290,0x291}},east=false,down=false,landing={1,2}},
  {pair='building__pokemon_center',rows={{0x298,0x299},{0x2A0,0x2A1},{0x2A8,0x2A9}},east=false,down=true,landing={1,2}},
 },
 -- stairs drawn as a doorway in the back wall, per tileset pair
 wall={
  building__brendans_mays_house={[0x211]='up',[0x214]='down'},
  building__generic_building={[0x20B]='up',[0x219]='down'}, -- Rustboro flats, Cove Lily Motel
  building__facility={[0x393]='up',[0x396]='down'}, -- Devon Corp
  general__facility={[0x393]='up',[0x396]='down',[0x2BC]='up',[0x2CC]='down'},
  building__shop={[0x250]='up',[0x251]='down'}, -- Lilycove Department Store
  building__oceanic_museum={[0x20E]='up',[0x20F]='down'},
  building__lilycove_museum={[0x20E]='up',[0x273]='down'},
  building__lab={[0x285]='up',[0x283]='down'}, -- Weather Institute
  building__mossdeep_game_corner={[0x20B]='up',[0x203]='down'},
  building__trainer_hill={[0x21E]='up',[0x219]='down'},
  building__sootopolis_gym={[0x21C]='up',[0x214]='down'},
 },
}
