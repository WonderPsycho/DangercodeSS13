
var/global/datum/controller/occupations/job_master

#define GET_RANDOM_JOB 0
#define BE_ASSISTANT 1
#define RETURN_TO_LOBBY 2

/datum/controller/occupations
	//List of all jobs
	var/list/occupations = list()
	var/list/name_occupations = list()	//Dict of all jobs, keys are titles
	var/list/type_occupations = list()	//Dict of all jobs, keys are types
	var/list/prioritized_jobs = list() // List of jobs set to priority by HoP/Captain
	//Players who need jobs
	var/list/unassigned = list()
	//Debug info
	var/list/job_debug = list()


/datum/controller/occupations/proc/SetupOccupations(var/list/faction = list("Station"))
	occupations = list()

	var/list/all_jobs = subtypesof(/datum/job)
	if(!all_jobs.len)
		to_chat(world, "<span class='warning'>Error setting up jobs, no job datums found</span>")
		return 0

	for(var/J in all_jobs)
		var/datum/job/job = new J()
		if(!job)
			continue
		if(!job.faction in faction)
			continue
		occupations += job
		name_occupations[job.title] = job
		type_occupations[J] = job

	return 1


/datum/controller/occupations/proc/Debug(var/text)
	if(!Debug2)
		return 0
	job_debug.Add(text)
	return 1


/datum/controller/occupations/proc/GetJob(rank)
	if(!occupations.len)
		SetupOccupations()
	return name_occupations[rank]

/datum/controller/occupations/proc/GetJobType(jobtype)
	if(!occupations.len)
		SetupOccupations()
	return type_occupations[jobtype]

/datum/controller/occupations/proc/GetPlayerAltTitle(mob/new_player/player, rank)
	return player.client.prefs.GetPlayerAltTitle(GetJob(rank))

/datum/controller/occupations/proc/AssignRole(var/mob/new_player/player, var/rank, var/latejoin = 0)
	Debug("Running AR, Player: [player], Rank: [rank], LJ: [latejoin]")
	if(player && player.mind && rank)
		var/datum/job/job = GetJob(rank)
		if(!job)
			return 0
		if(jobban_isbanned(player, rank))
			return 0
		if(!job.player_old_enough(player.client))
			return 0
		if(job.available_in_playtime(player.client))
			return 0
		if(!is_job_whitelisted(player, rank))
			return 0

		var/position_limit = job.total_positions
		if(!latejoin)
			position_limit = job.spawn_positions

		if((job.current_positions < position_limit) || position_limit == -1)
			Debug("Player: [player] is now Rank: [rank], JCP:[job.current_positions], JPL:[position_limit]")
			player.mind.assigned_role = rank
			player.mind.role_alt_title = GetPlayerAltTitle(player, rank)

			// JOB OBJECTIVES OH SHIT
			player.mind.job_objectives.Cut()
			for(var/objectiveType in job.required_objectives)
				new objectiveType(player.mind)

			// 50/50 chance of getting optional objectives.
			for(var/objectiveType in job.optional_objectives)
				if(prob(50))
					new objectiveType(player.mind)

			unassigned -= player
			job.current_positions++
			return 1

	Debug("AR has failed, Player: [player], Rank: [rank]")
	return 0

/datum/controller/occupations/proc/FreeRole(var/rank)	//making additional slot on the fly
	var/datum/job/job = GetJob(rank)
	if(job && job.current_positions >= job.total_positions && job.total_positions != -1)
		job.total_positions++
		return 1
	return 0

/datum/controller/occupations/proc/FindOccupationCandidates(datum/job/job, level, flag)
	Debug("Running FOC, Job: [job], Level: [level], Flag: [flag]")
	var/list/candidates = list()
	for(var/mob/new_player/player in unassigned)
		Debug(" - Player: [player] Banned: [jobban_isbanned(player, job.title)] Old Enough: [!job.player_old_enough(player.client)] AvInPlaytime: [job.available_in_playtime(player.client)] Flag && Be Special: [flag] && [player.client.prefs.be_special] Job Department: [player.client.prefs.GetJobDepartment(job, level)] Job Flag: [job.flag] Job Department Flag = [job.department_flag]")
		if(jobban_isbanned(player, job.title))
			Debug("FOC isbanned failed, Player: [player]")
			continue
		if(!job.player_old_enough(player.client))
			Debug("FOC player not old enough, Player: [player]")
			continue
		if(job.available_in_playtime(player.client))
			Debug("FOC player not enough playtime, Player: [player]")
			continue
		if(flag && !(flag in player.client.prefs.be_special))
			Debug("FOC flag failed, Player: [player], Flag: [flag], ")
			continue
		if(player.mind && job.title in player.mind.restricted_roles)
			Debug("FOC incompatbile with antagonist role, Player: [player]")
			continue
		if(player.client.prefs.GetJobDepartment(job, level) & job.flag)
			Debug("FOC pass, Player: [player], Level:[level]")
			candidates += player
	return candidates

/datum/controller/occupations/proc/GiveRandomJob(var/mob/new_player/player)
	Debug("GRJ Giving random job, Player: [player]")
	for(var/datum/job/job in shuffle(occupations))
		if(!job)
			continue

		if(istype(job, GetJob("Civilian"))) // We don't want to give him assistant, that's boring!
			continue

		if(job.title in command_positions) //If you want a command position, select it!
			continue

		if(job.title in whitelisted_positions) // No random whitelisted job, sorry!
			continue

		if(job.admin_only) // No admin positions either.
			continue

		if(jobban_isbanned(player, job.title))
			Debug("GRJ isbanned failed, Player: [player], Job: [job.title]")
			continue

		if(!job.player_old_enough(player.client))
			Debug("GRJ player not old enough, Player: [player]")
			continue

		if(job.available_in_playtime(player.client))
			Debug("GRJ player not enough playtime, Player: [player]")
			continue

		if(player.mind && job.title in player.mind.restricted_roles)
			Debug("GRJ incompatible with antagonist role, Player: [player], Job: [job.title]")
			continue

		if((job.current_positions < job.spawn_positions) || job.spawn_positions == -1)
			Debug("GRJ Random job given, Player: [player], Job: [job]")
			AssignRole(player, job.title)
			unassigned -= player
			break

/datum/controller/occupations/proc/ResetOccupations()
	for(var/mob/new_player/player in player_list)
		if((player) && (player.mind))
			player.mind.assigned_role = null
			player.mind.special_role = null
	SetupOccupations()
	unassigned = list()
	return


///This proc is called before the level loop of DivideOccupations() and will try to select a head, ignoring ALL non-head preferences for every level until it locates a head or runs out of levels to check
/datum/controller/occupations/proc/FillHeadPosition()
	for(var/level = 1 to 3)
		for(var/command_position in command_positions)
			var/datum/job/job = GetJob(command_position)
			if(!job)
				continue
			var/list/candidates = FindOccupationCandidates(job, level)
			if(!candidates.len)
				continue

			// Build a weighted list, weight by age.
			var/list/weightedCandidates = list()

			// Different head positions have different good ages.
			var/good_age_minimal = 25
			var/good_age_maximal = 60
			if(command_position == "Captain")
				good_age_minimal = 30
				good_age_maximal = 70 // Old geezer captains ftw

			for(var/mob/V in candidates)
				// Log-out during round-start? What a bad boy, no head position for you!
				if(!V.client)
					continue
				var/age = V.client.prefs.age
				switch(age)
					if(good_age_minimal - 10 to good_age_minimal)
						weightedCandidates[V] = 3 // Still a bit young.
					if(good_age_minimal to good_age_minimal + 10)
						weightedCandidates[V] = 6 // Better.
					if(good_age_minimal + 10 to good_age_maximal - 10)
						weightedCandidates[V] = 10 // Great.
					if(good_age_maximal - 10 to good_age_maximal)
						weightedCandidates[V] = 6 // Still good.
					if(good_age_maximal to good_age_maximal + 10)
						weightedCandidates[V] = 6 // Bit old, don't you think?
					if(good_age_maximal to good_age_maximal + 50)
						weightedCandidates[V] = 3 // Geezer.
					else
						// If there's ABSOLUTELY NOBODY ELSE
						if(candidates.len == 1)
							weightedCandidates[V] = 1

			var/mob/new_player/candidate = pickweight(weightedCandidates)
			if(AssignRole(candidate, command_position))
				return 1

	return 0


///This proc is called at the start of the level loop of DivideOccupations() and will cause head jobs to be checked before any other jobs of the same level
/datum/controller/occupations/proc/CheckHeadPositions(var/level)
	for(var/command_position in command_positions)
		var/datum/job/job = GetJob(command_position)
		if(!job)
			continue
		var/list/candidates = FindOccupationCandidates(job, level)
		if(!candidates.len)
			continue
		var/mob/new_player/candidate = pick(candidates)
		AssignRole(candidate, command_position)


/datum/controller/occupations/proc/FillAIPosition()
	if(config && !config.allow_ai)
		return 0

	var/ai_selected = 0
	var/datum/job/job = GetJob("AI")
	if(!job)
		return 0

	for(var/i = job.total_positions, i > 0, i--)
		for(var/level = 1 to 3)
			var/list/candidates = list()
			candidates = FindOccupationCandidates(job, level)
			if(candidates.len)
				var/mob/new_player/candidate = pick(candidates)
				if(AssignRole(candidate, "AI"))
					ai_selected++
					break

		if(ai_selected)
			return 1

		return 0


/** Proc DivideOccupations
*  fills var "assigned_role" for all ready players.
*  This proc must not have any side effect besides of modifying "assigned_role".
**/
/datum/controller/occupations/proc/DivideOccupations()
	//Setup new player list and get the jobs list
	Debug("Running DO")
	SetupOccupations()

	//Holder for Triumvirate is stored in the ticker, this just processes it
	if(ticker)
		for(var/datum/job/ai/A in occupations)
			if(ticker.triai)
				A.spawn_positions = 3

	//Get the players who are ready
	for(var/mob/new_player/player in player_list)
		if(player.ready && player.mind && !player.mind.assigned_role)
			unassigned += player
			if(player.client.prefs.randomslot)
				player.client.prefs.load_random_character_slot(player.client)

	Debug("DO, Len: [unassigned.len]")
	if(unassigned.len == 0)
		return 0

	//Shuffle players and jobs
	unassigned = shuffle(unassigned)

	HandleFeedbackGathering()

	//People who wants to be assistants, sure, go on.
	Debug("DO, Running Civilian Check 1")
	var/datum/job/civ = new /datum/job/civilian()
	var/list/civilian_candidates = FindOccupationCandidates(civ, 3)
	Debug("AC1, Candidates: [civilian_candidates.len]")
	for(var/mob/new_player/player in civilian_candidates)
		Debug("AC1 pass, Player: [player]")
		AssignRole(player, "Civilian")
		civilian_candidates -= player
	Debug("DO, AC1 end")

	//Select one head
	Debug("DO, Running Head Check")
	FillHeadPosition()
	Debug("DO, Head Check end")

	//Check for an AI
	Debug("DO, Running AI Check")
	FillAIPosition()
	Debug("DO, AI Check end")

	//Other jobs are now checked
	Debug("DO, Running Standard Check")


	// New job giving system by Donkie
	// This will cause lots of more loops, but since it's only done once it shouldn't really matter much at all.
	// Hopefully this will add more randomness and fairness to job giving.

	// Loop through all levels from high to low
	var/list/shuffledoccupations = shuffle(occupations)
	for(var/level = 1 to 3)
		//Check the head jobs first each level
		CheckHeadPositions(level)

		// Loop through all unassigned players
		for(var/mob/new_player/player in unassigned)

			// Loop through all jobs
			for(var/datum/job/job in shuffledoccupations) // SHUFFLE ME BABY
				if(!job)
					continue

				if(jobban_isbanned(player, job.title))
					Debug("DO isbanned failed, Player: [player], Job:[job.title]")
					continue

				if(!job.player_old_enough(player.client))
					Debug("DO player not old enough, Player: [player], Job:[job.title]")
					continue

				if(job.available_in_playtime(player.client))
					Debug("DO player not enough playtime, Player: [player], Job:[job.title]")
					continue

				if(player.mind && job.title in player.mind.restricted_roles)
					Debug("DO incompatible with antagonist role, Player: [player], Job:[job.title]")
					continue

				if(!is_job_whitelisted(player, job.title))
					Debug("DO player not whitelisted, Player: [player], Job:[job.title]")
					continue

				// If the player wants that job on this level, then try give it to him.
				if(player.client.prefs.GetJobDepartment(job, level) & job.flag)

					// If the job isn't filled
					if((job.current_positions < job.spawn_positions) || job.spawn_positions == -1)
						Debug("DO pass, Player: [player], Level:[level], Job:[job.title]")
						Debug(" - Job Flag: [job.flag] Job Department: [player.client.prefs.GetJobDepartment(job, level)] Job Current Pos: [job.current_positions] Job Spawn Positions = [job.spawn_positions]")
						AssignRole(player, job.title)
						unassigned -= player
						break

	// Hand out random jobs to the people who didn't get any in the last check
	// Also makes sure that they got their preference correct
	for(var/mob/new_player/player in unassigned)
		if(player.client.prefs.alternate_option == GET_RANDOM_JOB)
			GiveRandomJob(player)

	Debug("DO, Standard Check end")

	Debug("DO, Running AC2")

	// Antags, who have to get in, come first
	for(var/mob/new_player/player in unassigned)
		if(player.mind.special_role)
			GiveRandomJob(player)
			if(player in unassigned)
				AssignRole(player, "Civilian")

	// Then we assign what we can to everyone else.
	for(var/mob/new_player/player in unassigned)
		if(player.client.prefs.alternate_option == BE_ASSISTANT)
			Debug("AC2 Assistant located, Player: [player]")
			AssignRole(player, "Civilian")
		else if(player.client.prefs.alternate_option == RETURN_TO_LOBBY)
			player.ready = 0
			unassigned -= player

	return 1


/datum/controller/occupations/proc/EquipRank(var/mob/living/carbon/human/H, var/rank, var/joined_late = 0)
	if(!H)
		return null

	var/datum/job/job = GetJob(rank)

	H.job = rank

	if(!joined_late)
		var/turf/T = null
		var/obj/S = null
		for(var/obj/effect/landmark/start/sloc in landmarks_list)
			if(sloc.name != rank)
				continue
			if(locate(/mob/living) in sloc.loc)
				continue
			S = sloc
			break
		if(!S)
			S = locate("start*[rank]") // use old stype
		if(!S) // still no spawn, fall back to the arrivals shuttle
			for(var/turf/TS in get_area_turfs(/area/shuttle/arrival))
				if(!TS.density)
					var/clear = 1
					for(var/obj/O in TS)
						if(O.density)
							clear = 0
							break
					if(clear)
						T = TS
						continue

		if(isturf(S))
			T = S
		else if(istype(S, /obj/effect/landmark/start) && isturf(S.loc))
			T = S.loc

		if(T)
			H.loc = T
			// Moving wheelchair if they have one
			if(H.buckled && istype(H.buckled, /obj/structure/stool/bed/chair/wheelchair))
				H.buckled.loc = H.loc
				H.buckled.dir = H.dir

	var/alt_title = null
	if(H.mind)
		H.mind.assigned_role = rank
		alt_title = H.mind.role_alt_title

		CreateMoneyAccount(H, rank, job)

	if(job)
		var/new_mob = job.equip(H)
		if(ismob(new_mob))
			H = new_mob

	to_chat(H, "<B>You are the [alt_title ? alt_title : rank].</B>")
	to_chat(H, "<b>As the [alt_title ? alt_title : rank] you answer directly to [job.supervisors]. Special circumstances may change this.</b>")
	to_chat(H, "<b>For more information on how the station works, see <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure\">Standard Operating Procedure (SOP)</a></b>")
	if(job.is_service)
		to_chat(H, "<b>As a member of Service, make sure to read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Service&#41\">Department SOP</a></b>")
	if(job.is_supply)
		to_chat(H, "<b>As a member of Supply, make sure to read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Supply&#41\">Department SOP</a></b>")
	if(job.is_command)
		to_chat(H, "<b>As an important member of Command, read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Command&#41\">Department SOP</a></b>")
	if(job.is_legal)
		to_chat(H, "<b>Your job requires complete knowledge of <a href=\"https://nanotrasen.se/wiki/index.php/Space_law\">Space Law</a> and <a href=\"https://nanotrasen.se/wiki/index.php/Legal_Standard_Operating_Procedure\">Legal Standard Operating Procedure</a></b>")
	if(job.is_engineering)
		to_chat(H, "<b>As a member of Engineering, make sure to read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Engineering&#41\">Department SOP</a></b>")
	if(job.is_medical)
		to_chat(H, "<b>As a member of Medbay, make sure to read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Medical&#41\">Department SOP</a></b>")
	if(job.is_science)
		to_chat(H, "<b>As a member of Science, make sure to read up on your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Science&#41\">Department SOP</a></b>")
	if(job.is_security)
		to_chat(H, "<b>As a member of Security, you are to know <a href=\"https://nanotrasen.se/wiki/index.php/Space_law\">Space Law</a>, <a href=\"https://nanotrasen.se/wiki/index.php/Legal_Standard_Operating_Procedure\">Legal Standard Operating Procedure</a>, as well as your <a href=\"https://nanotrasen.se/wiki/index.php/Standard_Operating_Procedure_&#40;Security&#41\">Department SOP</a></b>")
	if(job.req_admin_notify)
		to_chat(H, "<b>You are playing a job that is important for the game progression. If you have to disconnect, please notify the admins via adminhelp.</b>")

	if(job && H)
		job.after_spawn(H)

		//Gives glasses to the vision impaired
		if(H.disabilities & DISABILITY_FLAG_NEARSIGHTED)
			var/equipped = H.equip_to_slot_or_del(new /obj/item/clothing/glasses/regular(H), slot_glasses)
			if(equipped != 1)
				var/obj/item/clothing/glasses/G = H.glasses
				if(istype(G) && !G.prescription)
					G.prescription = 1
					G.name = "prescription [G.name]"
	return H





/datum/controller/occupations/proc/LoadJobs(jobsfile) //ran during round setup, reads info from jobs.txt -- Urist
	if(!config.load_jobs_from_txt)
		return 0

	var/list/jobEntries = file2list(jobsfile)

	for(var/job in jobEntries)
		if(!job)
			continue

		job = trim(job)
		if(!length(job))
			continue

		var/pos = findtext(job, "=")
		var/name = null
		var/value = null

		if(pos)
			name = copytext(job, 1, pos)
			value = copytext(job, pos + 1)
		else
			continue

		if(name && value)
			var/datum/job/J = GetJob(name)
			if(!J)	continue
			J.total_positions = text2num(value)
			J.spawn_positions = text2num(value)
			if(name == "AI" || name == "Cyborg")//I dont like this here but it will do for now
				J.total_positions = 0

	return 1


/datum/controller/occupations/proc/HandleFeedbackGathering()
	for(var/datum/job/job in occupations)
		var/tmp_str = "|[job.title]|"

		var/level1 = 0 //high
		var/level2 = 0 //medium
		var/level3 = 0 //low
		var/level4 = 0 //never
		var/level5 = 0 //banned
		var/level6 = 0 //account too young
		for(var/mob/new_player/player in player_list)
			if(!(player.ready && player.mind && !player.mind.assigned_role))
				continue //This player is not ready
			if(jobban_isbanned(player, job.title))
				level5++
				continue
			if(!job.player_old_enough(player.client))
				level6++
				continue
			if(job.available_in_playtime(player.client))
				level6++
				continue
			if(player.client.prefs.GetJobDepartment(job, 1) & job.flag)
				level1++
			else if(player.client.prefs.GetJobDepartment(job, 2) & job.flag)
				level2++
			else if(player.client.prefs.GetJobDepartment(job, 3) & job.flag)
				level3++
			else level4++ //not selected

		tmp_str += "HIGH=[level1]|MEDIUM=[level2]|LOW=[level3]|NEVER=[level4]|BANNED=[level5]|YOUNG=[level6]|-"
		feedback_add_details("job_preferences",tmp_str)


/datum/controller/occupations/proc/CreateMoneyAccount(mob/living/H, rank, datum/job/job)
	var/datum/money_account/M = create_account(H.real_name, rand(50,500)*10, null)
	var/remembered_info = ""

	remembered_info += "<b>Your account number is:</b> #[M.account_number]<br>"
	remembered_info += "<b>Your account pin is:</b> [M.remote_access_pin]<br>"
	remembered_info += "<b>Your account funds are:</b> $[M.money]<br>"

	if(M.transaction_log.len)
		var/datum/transaction/T = M.transaction_log[1]
		remembered_info += "<b>Your account was created:</b> [T.time], [T.date] at [T.source_terminal]<br>"
	H.mind.store_memory(remembered_info)

	// If they're head, give them the account info for their department
	if(job && job.head_position)
		remembered_info = ""
		var/datum/money_account/department_account = department_accounts[job.department]

		if(department_account)
			remembered_info += "<b>Your department's account number is:</b> #[department_account.account_number]<br>"
			remembered_info += "<b>Your department's account pin is:</b> [department_account.remote_access_pin]<br>"
			remembered_info += "<b>Your department's account funds are:</b> $[department_account.money]<br>"

		H.mind.store_memory(remembered_info)

	H.mind.initial_account = M

	spawn(0)
		to_chat(H, "<span class='boldnotice'>Your account number is: [M.account_number], your account pin is: [M.remote_access_pin]</span>")
