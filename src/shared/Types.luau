--!strict
-- Shared type definitions for player data and network payloads.

export type Stats = {
	MiningPower: number,
	MiningLuck: number,
	FishingPower: number,
	FishingSpeed: number,
	FishingLuck: number,
}

export type OwnedPet = {
	uid: string,
	id: string,
	obtainedAt: number,
}

export type Profile = {
	version: number,
	coins: { [string]: number },
	rebirths: number,
	currentWorld: string,
	stats: { [string]: number }, -- reset on rebirth; drives rebirth tasks
	lifetime: { [string]: number }, -- never reset
	pets: { OwnedPet },
	equipped: { string }, -- pet uids
}

export type HatchResult = {
	ok: boolean,
	message: string?,
	pet: OwnedPet?,
}

export type RebirthResult = {
	ok: boolean,
	message: string?,
	rebirths: number?,
}

export type SimpleResult = {
	ok: boolean,
	message: string?,
}

-- Type-only module; ModuleScripts must still return a value.
return {}
