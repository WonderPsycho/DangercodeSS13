/* Holograms!
 * Contains:
 *		Holopad
 *		Hologram
 *		Other stuff
 */

/*
Revised. Original based on space ninja hologram code. Which is also mine. /N
How it works:
AI clicks on holopad in camera view. View centers on holopad.
AI clicks again on the holopad to display a hologram. Hologram stays as long as AI is looking at the pad and it (the hologram) is in range of the pad.
AI can use the directional keys to move the hologram around, provided the above conditions are met and the AI in question is the holopad's master.
Only one AI may project from a holopad at any given time.
AI may cancel the hologram at any time by clicking on the holopad once more.

Possible to do for anyone motivated enough:
	Give an AI variable for different hologram icons.
	Itegrate EMP effect to disable the unit.
*/


/*
 * Holopad
 */

// HOLOPAD MODE
// 0 = RANGE BASED
// 1 = AREA BASED
var/const/HOLOPAD_MODE = 0
var/list/holopads = list()

/obj/machinery/hologram/holopad
	name = "\improper AI holopad"
	desc = "It's a floor-mounted device for projecting holographic images. It is activated remotely."
	icon_state = "holopad0"

	layer = TURF_LAYER+0.1 //Preventing mice and drones from sneaking under them.

	var/mob/living/silicon/ai/master//Which AI, if any, is controlling the object? Only one AI may control a hologram at any time.
	var/last_request = 0 //to prevent request spam. ~Carn
	var/holo_range = 5 // Change to change how far the AI can move away from the holopad before deactivating.

/obj/machinery/hologram/holopad/New()
	..()
	holopads += src
	component_parts = list()
	component_parts += new /obj/item/weapon/circuitboard/holopad(null)
	component_parts += new /obj/item/weapon/stock_parts/capacitor(null)
	RefreshParts()

/obj/machinery/hologram/holopad/RefreshParts()
	var/holograph_range = 4
	for(var/obj/item/weapon/stock_parts/capacitor/B in component_parts)
		holograph_range += 1 * B.rating
	holo_range = holograph_range

/obj/machinery/hologram/holopad/attackby(obj/item/P as obj, mob/user as mob, params)
	if(default_deconstruction_screwdriver(user, "holopad_open", "holopad0", P))
		return

	if(exchange_parts(user, P))
		return

	if(default_unfasten_wrench(user, P))
		return

	default_deconstruction_crowbar(P)


/obj/machinery/hologram/holopad/attack_hand(var/mob/living/carbon/human/user) //Carn: Hologram requests.
	if(!istype(user))
		return
	if(alert(user,"Would you like to request an AI's presence?",,"Yes","No") == "Yes")
		if(last_request + 200 < world.time) //don't spam the AI with requests you jerk!
			last_request = world.time
			to_chat(user, "<span class='notice'>You request an AI's presence.</span>")
			var/area/area = get_area(src)
			for(var/mob/living/silicon/ai/AI in living_mob_list)
				if(!AI.client)	continue
				to_chat(AI, "<span class='info'>Your presence is requested at <a href='?src=[AI.UID()];jumptoholopad=\ref[src]'>\the [area]</a>.</span>")
		else
			to_chat(user, "<span class='notice'>A request for AI presence was already sent recently.</span>")

/obj/machinery/hologram/holopad/attack_ai(mob/living/silicon/ai/user)
	if(!istype(user))
		return
	/*There are pretty much only three ways to interact here.
	I don't need to check for client since they're clicking on an object.
	This may change in the future but for now will suffice.*/
	if(user.eyeobj.loc != src.loc)//Set client eye on the object if it's not already.
		user.eyeobj.setLoc(get_turf(src))
	else if(!hologram)//If there is no hologram, possibly make one.
		activate_holo(user, 0)
	else if(master == user)//If there is a hologram, remove it. But only if the user is the master. Otherwise do nothing.
		clear_holo()
	return

/obj/machinery/hologram/holopad/proc/activate_holo(mob/living/silicon/ai/user, var/force = 0)
	if(!force && user.eyeobj.loc != src.loc) // allows holopads to pass off holograms to the next holopad in the chain
		to_chat(user, "<font color='red'>ERROR:</font> Unable to project hologram.")
	else if(!(stat & NOPOWER))//If the projector has power
		if(user.holo)
			var/obj/machinery/hologram/holopad/current = user.holo
			current.clear_holo()
		if(!hologram)//If there is not already a hologram.
			create_holo(user)//Create one.
			src.visible_message("A holographic image of [user] flicks to life right before your eyes!")
		else
			to_chat(user, "<font color='red'>ERROR:</font> Image feed in progress.")
	else
		to_chat(user, "<font color='red'>ERROR:</font> Unable to project hologram.")
	return

/*This is the proc for special two-way communication between AI and holopad/people talking near holopad.
For the other part of the code, check silicon say.dm. Particularly robot talk.*/
/obj/machinery/hologram/holopad/hear_talk(mob/living/M, text, verb, datum/language/speaking)
	if(M && hologram && master)//Master is mostly a safety in case lag hits or something.
		master.relay_speech(M, text, verb, speaking)

/obj/machinery/hologram/holopad/hear_message(mob/living/M, text)
	if(M&&hologram&&master)//Master is mostly a safety in case lag hits or something.
		var/name_used = M.GetVoice()
		var/rendered = "<i><span class='game say'>Holopad received, <span class='name'>[name_used]</span> [text]</span></i>"
		master.show_message(rendered, 2)
	return

/obj/machinery/hologram/holopad/proc/create_holo(mob/living/silicon/ai/A, turf/T = loc)
	hologram = new(T)//Spawn a blank effect at the location.
	hologram.icon = A.holo_icon
	if(A.holo_width > 32)
		var/icon_width = A.holo_width
		var/slide_x_amount = round((icon_width / 4)*-1)
		hologram.pixel_x = slide_x_amount
	hologram.mouse_opacity = 0//So you can't click on it.
	hologram.layer = FLY_LAYER//Above all the other objects/mobs. Or the vast majority of them.
	hologram.anchored = 1//So space wind cannot drag it.
	hologram.name = "[A.name] (Hologram)"//If someone decides to right click.
	hologram.set_light(2)	//hologram lighting
	set_light(2)			//pad lighting
	icon_state = "holopad1"
	A.holo = src
	master = A//AI is the master.
	use_power = 2//Active power usage.
	return 1

/obj/machinery/hologram/holopad/proc/clear_holo()
//	hologram.set_light(0)//Clear lighting.	//handled by the lighting controller when its ower is deleted
	QDEL_NULL(hologram)//Get rid of hologram.
	if(master.holo == src)
		master.holo = null
	master = null//Null the master, since no-one is using it now.
	set_light(0)			//pad lighting (hologram lighting will be handled automatically since its owner was deleted)
	icon_state = "holopad0"
	use_power = 1//Passive power usage.
	return 1

/obj/machinery/hologram/holopad/process()
	if(hologram)//If there is a hologram.
		if(master && !master.stat && master.client && master.eyeobj)//If there is an AI attached, it's not incapacitated, it has a client, and the client eye is centered on the projector.
			if(!(stat & NOPOWER))//If the  machine has power.
				if((HOLOPAD_MODE == 0 && (get_dist(master.eyeobj, src) <= holo_range)))
					return 1

				else if(HOLOPAD_MODE == 1)

					var/area/holo_area = get_area(src)
					var/area/eye_area = get_area(master.eyeobj)

					if(eye_area != holo_area)
						return 1

		var/mob/living/silicon/ai/theai = master
		var/turf/target_turf = get_turf(master.eyeobj)
		var/newdir = hologram.dir
		clear_holo()//If not, we want to get rid of the hologram.
		var/obj/machinery/hologram/holopad/pad_close = get_closest_atom(/obj/machinery/hologram/holopad, holopads, theai.eyeobj)
		if(get_dist(pad_close, theai.eyeobj) <= pad_close.holo_range)
			if(!(pad_close.stat & NOPOWER) && !pad_close.hologram)
				pad_close.activate_holo(theai, 1)
				if(pad_close.hologram)
					pad_close.hologram.forceMove(target_turf)
					pad_close.hologram.dir = newdir
	return 1

/obj/machinery/hologram/holopad/proc/move_hologram()
	if(hologram)
		step_to(hologram, master.eyeobj) // So it turns.
		hologram.loc = get_turf(master.eyeobj)

	return 1

// Simple helper to face what you clicked on, in case it should be needed in more than one place
/obj/machinery/hologram/holopad/proc/face_atom(var/atom/A)
	if( !hologram || !A || !hologram.x || !hologram.y || !A.x || !A.y ) return
	var/dx = A.x - hologram.x
	var/dy = A.y - hologram.y
	if(!dx && !dy) // Wall items are graphically shifted but on the floor
		if(A.pixel_y > 16)		hologram.dir = NORTH
		else if(A.pixel_y < -16)hologram.dir = SOUTH
		else if(A.pixel_x > 16)	hologram.dir = EAST
		else if(A.pixel_x < -16)hologram.dir = WEST
		return

	if(abs(dx) < abs(dy))
		if(dy > 0)	hologram.dir = NORTH
		else		hologram.dir = SOUTH
	else
		if(dx > 0)	hologram.dir = EAST
		else		hologram.dir = WEST

/*
 * Hologram
 */

/obj/machinery/hologram
	anchored = 1
	use_power = 1
	idle_power_usage = 5
	active_power_usage = 100
	var/obj/effect/overlay/hologram//The projection itself. If there is one, the instrument is on, off otherwise.

//Destruction procs.
/obj/machinery/hologram/ex_act(severity)
	switch(severity)
		if(1.0)
			qdel(src)
		if(2.0)
			if(prob(50))
				qdel(src)
		if(3.0)
			if(prob(5))
				qdel(src)
	return

/obj/machinery/hologram/blob_act()
	qdel(src)
	return

/obj/machinery/hologram/holopad/Destroy()
	holopads -= src
	if(hologram)
		clear_holo()
	return ..()

/*
Holographic project of everything else.

/mob/verb/hologram_test()
	set name = "Hologram Debug New"
	set category = "CURRENT DEBUG"

	var/obj/effect/overlay/hologram = new(loc)//Spawn a blank effect at the location.
	var/icon/flat_icon = icon(getFlatIcon(src,0))//Need to make sure it's a new icon so the old one is not reused.
	flat_icon.ColorTone(rgb(125,180,225))//Let's make it bluish.
	flat_icon.ChangeOpacity(0.5)//Make it half transparent.
	var/input = input("Select what icon state to use in effect.",,"")
	if(input)
		var/icon/alpha_mask = new('icons/effects/effects.dmi', "[input]")
		flat_icon.AddAlphaMask(alpha_mask)//Finally, let's mix in a distortion effect.
		hologram.icon = flat_icon

		to_chat(world, "Your icon should appear now.")
	return
*/

/*
 * Other Stuff: Is this even used?
 */
/obj/machinery/hologram/projector
	name = "hologram projector"
	desc = "It makes a hologram appear...with magnets or something..."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "hologram0"
