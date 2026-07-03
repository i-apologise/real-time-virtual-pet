extends Node
## Stub — routes between town / house / park / store / graveyard.

enum Poi { TOWN, HOUSE, PARK, STORE, GRAVEYARD }

func describe_poi(poi: Poi) -> String:
	match poi:
		Poi.TOWN:
			return "Town"
		Poi.HOUSE:
			return "Player House"
		Poi.PARK:
			return "Pet Park"
		Poi.STORE:
			return "Pet Store"
		Poi.GRAVEYARD:
			return "Graveyard"
		_:
			return "Unknown"
