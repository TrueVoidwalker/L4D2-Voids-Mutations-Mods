Msg("Activating Mutation Halo\n");

DirectorOptions <-
{
	weaponsToConvert =
	{
		weapon_sniper_awp				= "weapon_sniper_military_spawn"
		weapon_sniper_scout				= "weapon_hunting_rifle_spawn"
		weapon_rifle_sg552				= "weapon_rifle_spawn"
		weapon_smg_mp5				= "weapon_smg_spawn"
	}

	function ConvertWeaponSpawn( classname )
	{
		if ( classname in weaponsToConvert )
		{
			return weaponsToConvert[classname];
		}
		return 0;
	}

	DefaultItems =
	[
		"weapon_pistol_magnum",
	]

	function GetDefaultItem( idx )
	{
		if ( idx < DefaultItems.len() )
		{
			return DefaultItems[idx];
		}
		return 0;
	}

	weaponsToRemove =
	{
		weapon_melee = 0
		weapon_upgradepack_explosive = 0
		weapon_upgradepack_incendiary = 0
		upgrade_item = 0
		ammo = 0
	}

	function AllowWeaponSpawn( classname )
	{
		if ( classname in weaponsToRemove )
		{
			return false;
		}
		return true;
	}

	function ShouldAvoidItem( classname )
	{
		if ( classname in weaponsToRemove )
		{
			return true;
		}
		return false;
	}
}

MutationState <-
{
	CurrentDifficulty = 1
	TankHealth = 4000
	FixSpecialClaw = 4
}

local player = null;

function OnGameEvent_player_spawn( params )
{
	player = GetPlayerFromUserID( params["userid"] );

	if ( player.IsSurvivor() )
	{
		if ( player.GetMaxHealth() < 115 )
		{
			local modifycurrenthealth = player.GetHealth() * 1.15;

			player.SetMaxHealth( 115 );
			player.SetHealth( modifycurrenthealth );
		}
		// Survivors spawn with medkits and pills in Survival
		if ( Director.GetGameModeBase() == "survival" )
		{
			player.GiveItem( "weapon_first_aid_kit" );
			player.GiveItem( "weapon_pain_pills" );
		}
		// Survivors spawn with pills in Helljumper
		else if ( Director.GetGameMode() == "voidhalocoophard" )
			player.GiveItem( "weapon_pain_pills" );
	}
}

function OnGameEvent_round_start_post_nav( params )
{
	CheckDifficultyForSpecialStats( GetDifficulty() );

	foreach( wep, val in DirectorOptions.weaponsToRemove )
		EntFire( wep + "_spawn", "Kill" );
	foreach( wep, val in DirectorOptions.weaponsToConvert )
	{
		for ( local wep_spawner; wep_spawner = Entities.FindByClassname( wep_spawner, wep + "_spawn" ); )
		{
			local spawnTable =
			{
				origin = wep_spawner.GetOrigin(),
				angles = wep_spawner.GetAngles().ToKVString(),
				targetname = wep_spawner.GetName(),
				count = NetProps.GetPropInt( wep_spawner, "m_itemCount" ),
				spawnflags = NetProps.GetPropInt( wep_spawner, "m_spawnflags" )
			}
			wep_spawner.Kill();
			SpawnEntityFromTable(val, spawnTable);
		}
	}
}

function OnGameEvent_difficulty_changed( params )
{
	CheckDifficultyForSpecialStats( params["newDifficulty"] );
}

function OnGameEvent_heal_success( params )
{
	player = GetPlayerFromUserID( params["subject"] );

	local HealTotal = (player.GetHealth() + 70);

	if ( HealTotal > player.GetMaxHealth() )
		HealTotal = player.GetMaxHealth();

	player.SetHealth( HealTotal );
}

function OnGameEvent_pills_used( params )
{
	player = GetPlayerFromUserID( params["subject"] );

	local playerHealth = player.GetHealth();
	local playerBufferHealth = player.GetHealthBuffer();
	local HealTotal = 70;

	if ( playerHealth >= 45 )
	{
		HealTotal = ( player.GetMaxHealth() - playerHealth );

		player.SetHealthBuffer( HealTotal );
	}
	else
	{
		HealTotal = (playerBufferHealth + 70 + floor( (playerHealth - 45) * 1.5555 ));

		if ( HealTotal > 70 )
			HealTotal = 70;

		player.SetHealth( 45 );
		player.SetHealthBuffer( HealTotal );
	}
}

function OnGameEvent_adrenaline_used( params )
{
	player = GetPlayerFromUserID( params["subject"] );

	local playerHealth = player.GetHealth();
	local playerBufferHealth = player.GetHealthBuffer();
	local HealTotal = 45;

	if ( playerHealth >= 45 )
	{
		HealTotal = ( playerHealth + playerBufferHealth + 30 );

		if ( HealTotal > player.GetMaxHealth() )
		{
			HealTotal = (player.GetMaxHealth() - playerHealth);

			player.SetHealthBuffer( HealTotal );
		}
		else
		{
			HealTotal = (HealTotal - playerHealth);

			player.SetHealthBuffer( HealTotal );
		}
	}
	else if ( playerHealth >= 30 )
	{
		HealTotal = (playerBufferHealth + floor( playerHealth * 0.6667 ));

		if ( HealTotal > 70 )
			HealTotal = 70;

		player.SetHealth( 45 );
		player.SetHealthBuffer( HealTotal );
	}
	else
	{
		HealTotal = (playerHealth + 15);

		player.SetHealth( HealTotal );
	}
}

function OnGameEvent_revive_success( params )
{
	player = GetPlayerFromUserID( params["subject"] );

	player.SetHealth( 45 );
	player.SetHealthBuffer( 70 );
}

function CheckDifficultyForSpecialStats( difficulty )
{
	SessionState.CurrentDifficulty = difficulty;

	local health = 0;
	if ( Director.GetGameModeBase() == "versus" )
		health = [6000, 6000, 6000, 6000];
	else
		health = [3000, 4000, 5000, 6000];
	
	SessionState.TankHealth = health[difficulty];
}

function OnGameEvent_tank_spawn( params )
{
	local tank = GetPlayerFromUserID( params["userid"] );
	if ( !tank )
		return;
	
	tank.SetMaxHealth( SessionState.TankHealth );
	tank.SetHealth( SessionState.TankHealth );
}

function AllowTakeDamage( damageTable )
{
	if ( !damageTable.Attacker || !damageTable.Victim || !damageTable.Inflictor )
		return true;

	if ( damageTable.Weapon != null && damageTable.Weapon.IsValid() && damageTable.Weapon.GetClassname() == "weapon_pistol_magnum" )
	{
		damageTable.DamageDone = (damageTable.DamageDone * 0.8);
		return true;
	}

	if ( damageTable.DamageType == 128 )
	{
		if ( damageTable.Attacker.IsPlayer() && damageTable.Victim.IsPlayer() )
		{
			if ( damageTable.Victim.IsSurvivor() && !damageTable.Attacker.IsSurvivor() )
			{
				if ( damageTable.Attacker.IsStaggering() )
					return false;

				if ( damageTable.Victim.GetSpecialInfectedDominatingMe() == damageTable.Attacker )
				{
					switch ( damageTable.Attacker.GetZombieType() )
					{
						case 3:	// Hunter
							SessionState.FixSpecialClaw = Convars.GetFloat( "z_pounce_damage" ); break;
						case 5:	// Jockey
							SessionState.FixSpecialClaw = Convars.GetFloat( "z_jockey_ride_damage" ); break;
						case 6:	// Charger
						{
							local ChargeAbility = NetProps.GetPropEntityArray( damageTable.Attacker, "m_customAbility", 0 );

							if ( NetProps.GetPropIntArray( ChargeAbility, "m_isCharging", 0 ) > 0 )
								SessionState.FixSpecialClaw = Convars.GetFloat( "z_charge_max_damage" );
							else
								SessionState.FixSpecialClaw = Convars.GetFloat( "z_charger_pound_dmg" );

							break;
						}
					}

					switch ( SessionState.CurrentDifficulty )
					{
						case 1:	// Normal
							damageTable.DamageDone = SessionState.FixSpecialClaw; break;
						case 2:	// Advanced
							damageTable.DamageDone = ( SessionState.FixSpecialClaw * 1.5 ); break;
						case 3:	// Expert
							damageTable.DamageDone = ( SessionState.FixSpecialClaw * 2 ); break;
						default:	// Easy/Other
							damageTable.DamageDone = ( SessionState.FixSpecialClaw / 2 ); break;
					}
				}
				else
				{
					switch ( damageTable.Attacker.GetZombieType() )
					{
						case 1:	// Smoker
							SessionState.FixSpecialClaw = Convars.GetFloat( "smoker_pz_claw_dmg" ); break;
						case 2:	// Boomer
							SessionState.FixSpecialClaw = Convars.GetFloat( "boomer_pz_claw_dmg" ); break;
						case 3:	// Hunter
							SessionState.FixSpecialClaw = Convars.GetFloat( "hunter_pz_claw_dmg" ); break;
						case 4:	// Spitter
							SessionState.FixSpecialClaw = Convars.GetFloat( "spitter_pz_claw_dmg" ); break;
						case 5:	// Jockey
							SessionState.FixSpecialClaw = Convars.GetFloat( "jockey_pz_claw_dmg" ); break;
						case 6:	// Charger
							SessionState.FixSpecialClaw = Convars.GetFloat( "charger_pz_claw_dmg" ); break;
						case 8:	// Tank
							SessionState.FixSpecialClaw = Convars.GetFloat( "vs_tank_damage" ); break;
					}

					switch ( SessionState.CurrentDifficulty )
					{
						case 1:	// Normal
							damageTable.DamageDone = SessionState.FixSpecialClaw; break;
						case 2:	// Advanced
							damageTable.DamageDone = ( SessionState.FixSpecialClaw * 1.5 ); break;
						case 3:	// Expert
							damageTable.DamageDone = ( SessionState.FixSpecialClaw * 2.5 ); break;
						default:	// Easy/Other
							damageTable.DamageDone = ( SessionState.FixSpecialClaw / 2 ); break;
					}
				}

				return true;
			}
		}
		else if ( damageTable.Attacker.GetClassname() == "infected" && damageTable.Victim.IsPlayer() )
		{
			if ( damageTable.Victim.IsSurvivor() )
			{
				switch ( SessionState.CurrentDifficulty )
				{
					case 1:	// Normal
						damageTable.DamageDone = 7; break;
					case 2:	// Advanced
						damageTable.DamageDone = 9; break;
					case 3:	// Expert
						damageTable.DamageDone = 13; break;
					default:	// Easy/Other
						damageTable.DamageDone = 1; break;
				}

				return true;
			}
		}
	}

	// Smoker choke damage
	if  ( damageTable.DamageType == 1048576 )
	{
		if ( damageTable.Attacker.GetZombieType() == 1 && damageTable.Victim.IsSurvivor() )
		{
			SessionState.FixSpecialClaw = Convars.GetFloat( "tongue_choke_damage_amount" );

			switch ( SessionState.CurrentDifficulty )
			{
				case 1:	// Normal
					damageTable.DamageDone = SessionState.FixSpecialClaw; break;
				case 2:	// Advanced
					damageTable.DamageDone = ( SessionState.FixSpecialClaw * 1.5 ); break;
				case 3:	// Expert
					damageTable.DamageDone = ( SessionState.FixSpecialClaw * 2 ); break;
				default:	// Easy/Other
					damageTable.DamageDone = ( SessionState.FixSpecialClaw / 2 ); break;
			}

			return true;
		}
	}

	// Spitter acid damage
	if  ( damageTable.DamageType == 265216 || damageTable.DamageType == 263168 )
	{
		if ( damageTable.Attacker.GetZombieType() == 4 && damageTable.Victim.IsSurvivor() )
		{
			if ( damageTable.DamageDone >= 1 )
			{
				switch ( SessionState.CurrentDifficulty )
				{
					case 1:	// Normal
						damageTable.DamageDone = 3; break;
					case 2:	// Advanced
						damageTable.DamageDone = 4; break;
					case 3:	// Expert
						damageTable.DamageDone = 5; break;
					default:	// Easy/Other
						damageTable.DamageDone = 1; break;
				}

				return true;
			}
		}
	}
	return true;
}