package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import com.gnits.smartcampusbackend.realtime.RealtimeHub;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.CrossOrigin;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api/analytics")
@CrossOrigin(origins = "*")
public class AnalyticsController {
    private final RoomRepository rooms;
    private final BookingRepository bookings;
    private final TimetableEntryRepository timetable;
    private final RealtimeHub hub;

    public AnalyticsController(RoomRepository rooms, BookingRepository bookings,
                               TimetableEntryRepository timetable, RealtimeHub hub) {
        this.rooms = rooms; this.bookings = bookings; this.timetable = timetable; this.hub = hub;
    }

    @GetMapping("/summary")
    public Map<String,Object> summary(@RequestParam(required=false) String date) {
        LocalDate d;
        try { d = date == null || date.isBlank() ? LocalDate.now() : LocalDate.parse(date); }
        catch (Exception e) { d = LocalDate.now(); }
        String day = d.getDayOfWeek().name();
        LocalTime now = LocalTime.now();
        int total = 0, available = 0, occupied = 0, maintenance = 0, reserved = 0;
        List<Map<String,Object>> live = new ArrayList<>();
        for (Room r : rooms.findAll()) {
            total++;
            String admin = r.getStatus() == null ? "AVAILABLE" : r.getStatus().toUpperCase(Locale.ROOT);
            if ("MAINTENANCE".equals(admin)) { maintenance++; continue; }
            if ("RESERVED".equals(admin)) { reserved++; continue; }
            boolean busy = timetable.findAll().stream().filter(e -> matches(e,r)).filter(e -> dayMatches(e.getDayOfWeek(),day))
                    .anyMatch(e -> e.getStartTime()!=null && e.getEndTime()!=null && now.isAfter(e.getStartTime()) && now.isBefore(e.getEndTime()));
            if (!busy) busy = bookings.findByBookingDateAndRoomIdAndStatusIgnoreCase(d,r.getRoomId(),"CONFIRMED").stream()
                    .anyMatch(b -> now.isAfter(b.getStartTime()) && now.isBefore(b.getEndTime()));
            if (busy) occupied++; else available++;
        }
        long upcoming = bookings.findAll().stream().filter(b -> "CONFIRMED".equalsIgnoreCase(b.getStatus()))
                .filter(b -> b.getBookingDate()!=null && !b.getBookingDate().isBefore(LocalDate.now())).count();
        Map<String,Object> out = new LinkedHashMap<>();
        out.put("date",d.toString()); out.put("totalRooms",total); out.put("availableNow",available);
        out.put("occupiedNow",occupied); out.put("maintenance",maintenance); out.put("reserved",reserved);
        out.put("timetableEntries",timetable.count()); out.put("upcomingBookings",upcoming);
        out.put("realtimeConnections",hub.connectedUsers());
        return out;
    }

    @GetMapping("/timetable-health")
    public Map<String,Object> timetableHealth() {
        List<TimetableEntry> entries=timetable.findAll();
        int missingRoom=0, missingTime=0, missingDay=0, invalidRange=0;
        Set<String> roomsSeen=new HashSet<>();
        for (TimetableEntry e:entries) {
            if (e.getRoomId()==null && (e.getLhNo()==null || e.getLhNo().isBlank())) missingRoom++; else if(e.getRoomId()!=null) roomsSeen.add("ID:"+e.getRoomId());
            if (e.getDayOfWeek()==null || e.getDayOfWeek().isBlank()) missingDay++;
            if (e.getStartTime()==null || e.getEndTime()==null) missingTime++;
            else if (!e.getStartTime().isBefore(e.getEndTime())) invalidRange++;
        }
        return Map.of("entries",entries.size(),"roomsReferenced",roomsSeen.size(),"missingRoom",missingRoom,
                "missingDay",missingDay,"missingTime",missingTime,"invalidTimeRange",invalidRange,
                "healthy",missingRoom==0 && missingDay==0 && missingTime==0 && invalidRange==0);
    }

    private static boolean matches(TimetableEntry e, Room r) {
        if (e.getRoomId()!=null && Objects.equals(e.getRoomId(),r.getRoomId())) return true;
        return norm(e.getLhNo()).equals(norm(r.getRoomNo())) && !norm(r.getRoomNo()).isBlank();
    }
    private static String norm(String s){return s==null?"":s.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]","");}
    private static boolean dayMatches(String a,String b){if(a==null||b==null)return false; a=a.trim().toUpperCase(Locale.ROOT); b=b.trim().toUpperCase(Locale.ROOT); return a.equals(b)||(a.length()>=3&&b.length()>=3&&a.substring(0,3).equals(b.substring(0,3)));}
}
