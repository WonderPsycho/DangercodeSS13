/datum/chemical_reaction/slime/slimefreeze/freeze(datum/reagents/holder)
	if(holder && holder.my_atom)
		var/turf/open/T = get_turf(holder.my_atom)
		if(istype(T))
			T.atmos_spawn_air("n2=50;TEMP=2.7")