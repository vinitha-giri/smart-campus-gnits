# V13 – Add Classroom building_id fix

Based on V12. Fixes the admin Add classroom failure caused by `rooms.building_id` being NOT NULL.

## What changed
- `RoomController.createRoom()` now infers `building_id` from the block prefix of the new room number by looking at an existing room in the same block.
- Supported block prefixes already present in the database include A, B, C, D, F and S.
- `RoomController.updateRoom()` also re-infers `building_id` if an edited room number is moved to a different block.
- No capacity hardcoding was introduced.
- Existing `rooms.capacity` remains the source of truth.
- Existing aliases/mappings remain untouched; they continue to point through `room_id`.

## Test
From `backend\smartcampusbackend`:

```
mvn clean
mvn spring-boot:run
```

Then in Admin → Manage Rooms → Add classroom, add a room such as `A-999` or `S-999`.
The backend should automatically assign the matching `building_id` and save the room.
