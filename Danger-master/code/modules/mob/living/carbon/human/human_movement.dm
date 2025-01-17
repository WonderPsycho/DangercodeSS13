/mob/living/carbon/human/movement_delay()
	. = 0
	. += ..()
	. += config.human_delay
	. += species.movement_delay(src)

/mob/living/carbon/human/Process_Spacemove(movement_dir = 0)

	if(..())
		return 1

	//Do we have a working jetpack?
	var/obj/item/weapon/tank/jetpack/thrust
	if(istype(back,/obj/item/weapon/tank/jetpack))
		thrust = back
	else if(istype(back,/obj/item/weapon/rig))
		var/obj/item/weapon/rig/rig = back
		for(var/obj/item/rig_module/maneuvering_jets/module in rig.installed_modules)
			thrust = module.jets
			break

	if(thrust)
		if((movement_dir || thrust.stabilizers) && thrust.allow_thrust(0.01, src))
			return 1
	return 0

/mob/living/carbon/human/mob_has_gravity()
	. = ..()
	if(!.)
		if(mob_negates_gravity())
			. = 1

/mob/living/carbon/human/mob_negates_gravity()
	return shoes && shoes.negates_gravity()

/mob/living/carbon/human/Move(NewLoc, direct)
	. = ..()
	if(.) // did we actually move?
		if(!lying && !buckled && !throwing)
			for(var/obj/item/organ/external/splinted in splinted_limbs)
				splinted.update_splints()

	if(!has_gravity(loc))
		return

	var/obj/item/clothing/shoes/S = shoes

	//Bloody footprints
	var/turf/T = get_turf(src)
	var/obj/item/organ/external/l_foot = get_organ("l_foot")
	var/obj/item/organ/external/r_foot = get_organ("r_foot")
	var/hasfeet = TRUE
	if(!l_foot && !r_foot)
		hasfeet = FALSE

	if(shoes)
		if(S.bloody_shoes && S.bloody_shoes[S.blood_state])
			var/obj/effect/decal/cleanable/blood/footprints/oldFP = locate(/obj/effect/decal/cleanable/blood/footprints) in T
			if(oldFP && oldFP.blood_state == S.blood_state && oldFP.basecolor == S.blood_color)
				return
			else
				//No oldFP or it's a different kind of blood
				S.bloody_shoes[S.blood_state] = max(0, S.bloody_shoes[S.blood_state] - BLOOD_LOSS_PER_STEP)
				createFootprintsFrom(shoes, dir, T)
				update_inv_shoes()
	else if(hasfeet)
		if(bloody_feet && bloody_feet[blood_state])
			var/obj/effect/decal/cleanable/blood/footprints/oldFP = locate(/obj/effect/decal/cleanable/blood/footprints) in T
			if(oldFP && oldFP.blood_state == blood_state && oldFP.basecolor == feet_blood_color)
				return
			else
				bloody_feet[blood_state] = max(0, bloody_feet[blood_state] - BLOOD_LOSS_PER_STEP)
				createFootprintsFrom(src, dir, T)
				update_inv_shoes()
	//End bloody footprints

	if(S)
		if(loc != NewLoc)
			return 0
		if(buckled || lying || throwing)
			return 0
		if(!has_gravity(src))
			return 0
		S.step_action(src)

/mob/living/carbon/human/handle_footstep(turf/T)
	if(..())
		if(shoes)//shoe sounds are handled in proc/step_action() in clothing.dm
			return 0
		if(buckled || lying || throwing)
			return 0
		if(!has_gravity(src))
			return 0
		if(species.silent_steps)
			return 0 //species is silent
		if(step_count < 2 || step_count == 3)
			return 0
		var/S_played = FALSE//set to TRUE if we played a footstep sound for return values
		var/S //Sound to play
		var/range = (world.view - 1)
		var/volume = 100
		if(m_intent == MOVE_INTENT_WALK)
			range -= 2 //Sneaky
			volume /= 2 //Half volume

		//Miiight want to do a pass on this for performance but it works right now so I'm not touching it much.
		var/leftstepsound = get_step_sound(src, "l")
		var/rightstepsound = get_step_sound(src, "r")

		if(step_count == 2)
			if(rightstepsound)
				S = rightstepsound
			else if(leftstepsound)//missing a foot
				S = leftstepsound

		if(step_count >= 4)
			step_count = 0
			if(leftstepsound)
				S = leftstepsound
			else if(rightstepsound)//missing a foot
				S = rightstepsound

		if(S)
			playsound(T, S, volume, 1, range)
			S_played = TRUE
		if(locate(/obj/structure/alien/weeds) in T)
			playsound(T, "step_puddle", volume, 1, range)
		if(S_played)
			return 1
		return 0
	return 0
