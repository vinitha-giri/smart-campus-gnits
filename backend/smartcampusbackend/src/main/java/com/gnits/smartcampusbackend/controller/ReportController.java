package com.gnits.smartcampusbackend.controller;

import com.gnits.smartcampusbackend.entity.Booking;
import com.gnits.smartcampusbackend.entity.Room;
import com.gnits.smartcampusbackend.entity.TimetableEntry;
import com.gnits.smartcampusbackend.repository.BookingRepository;
import com.gnits.smartcampusbackend.repository.RoomRepository;
import com.gnits.smartcampusbackend.repository.TimetableEntryRepository;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

@RestController
@RequestMapping("/api/reports")
@CrossOrigin(origins = "*")
public class ReportController {
    private static final List<String> DAYS = List.of("MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY");
    private final RoomRepository roomRepository;
    private final TimetableEntryRepository timetableRepository;
    private final BookingRepository bookingRepository;

    public ReportController(RoomRepository roomRepository, TimetableEntryRepository timetableRepository, BookingRepository bookingRepository) {
        this.roomRepository = roomRepository; this.timetableRepository = timetableRepository; this.bookingRepository = bookingRepository;
    }

    @GetMapping("/summary")
    public Map<String, Object> summary(@RequestParam(required = false) String academicYear,
                                        @RequestParam(required = false) Integer semesterNo,
                                        @RequestParam(required = false) String sectionName) {
        List<TimetableEntry> entries = filteredEntries(academicYear, semesterNo, sectionName);
        LocalDate today = LocalDate.now(); LocalTime now = LocalTime.now(); String todayName = today.getDayOfWeek().name();
        List<Room> rooms = roomRepository.findAll();
        long operational = rooms.stream().filter(r -> !isSpecial(r.getStatus())).count();
        Set<String> sections = new TreeSet<>(String.CASE_INSENSITIVE_ORDER); Set<String> subjects = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        Map<String,Integer> dayCounts = new LinkedHashMap<>(); DAYS.forEach(d -> dayCounts.put(d, 0)); Map<String,Integer> roomCounts = new HashMap<>();
        for (TimetableEntry e: entries) { sections.add(e.getSectionName()); subjects.add(e.getSubjectName()); dayCounts.computeIfPresent(e.getDayOfWeek(), (k,v)->v+1); roomCounts.merge(e.getLhNo(),1,Integer::sum); }
        List<TimetableEntry> todayEntries = entries.stream().filter(e -> todayName.equalsIgnoreCase(e.getDayOfWeek())).toList();
        long scheduledToday = todayEntries.size();
        Set<Integer> activeRooms = new HashSet<>();
        for (Room r: rooms) {
            if (isSpecial(r.getStatus())) continue;
            boolean activeTT = todayEntries.stream().anyMatch(e -> roomMatches(e, r) && overlaps(now,e.getStartTime(),e.getEndTime()));
            boolean activeBooking = bookingRepository.findByBookingDateAndRoomIdAndStatusIgnoreCase(today,r.getRoomId(),"CONFIRMED").stream().anyMatch(b -> overlaps(now,b.getStartTime(),b.getEndTime()));
            if (activeTT || activeBooking) activeRooms.add(r.getRoomId());
        }
        long maintenance = rooms.stream().filter(r -> "MAINTENANCE".equalsIgnoreCase(r.getStatus())).count();
        long occupied = activeRooms.size(); long available = Math.max(0, operational - occupied);
        long bookingsToday = bookingRepository.findByBookingDateAndStatusIgnoreCase(today,"CONFIRMED").size();
        double currentUtilization = operational == 0 ? 0 : Math.round((occupied * 1000.0 / operational))/10.0;
        List<Map<String,Object>> roomUtilization = roomCounts.entrySet().stream().sorted(Map.Entry.<String,Integer>comparingByValue().reversed()).limit(10).map(e -> Map.<String,Object>of("roomNo",e.getKey(),"scheduledSlots",e.getValue())).toList();
        Map<String,Object> out = new LinkedHashMap<>();
        out.put("totalRooms", rooms.size()); out.put("operationalRooms", operational); out.put("availableRooms", available); out.put("occupiedRooms", occupied); out.put("maintenanceRooms", maintenance);
        out.put("scheduledToday", scheduledToday); out.put("activeNow", occupied); out.put("bookingsToday", bookingsToday); out.put("currentUtilizationPercent", currentUtilization);
        out.put("scheduledSlots", entries.size()); out.put("sections", sections.size()); out.put("subjects", subjects.size()); out.put("sectionNames", sections); out.put("dayCounts", dayCounts); out.put("roomUtilization", roomUtilization); out.put("today", todayName); out.put("currentTime", now.toString()); out.put("generatedAt", java.time.LocalDateTime.now().toString());
        return out;
    }

    @GetMapping("/day")
    public ResponseEntity<?> dayDetails(@RequestParam String day, @RequestParam(required=false) String academicYear, @RequestParam(required=false) Integer semesterNo, @RequestParam(required=false) String sectionName) {
        String selected = day.trim().toUpperCase(Locale.ROOT); if (!DAYS.contains(selected)) return ResponseEntity.badRequest().body(Map.of("success",false,"error","Invalid day."));
        List<TimetableEntry> entries = filteredEntries(academicYear,semesterNo,sectionName).stream().filter(e->selected.equalsIgnoreCase(e.getDayOfWeek())).sorted(Comparator.comparing(TimetableEntry::getStartTime).thenComparing(e->Objects.toString(e.getLhNo(),""))).toList();
        List<Map<String,Object>> timetable = new ArrayList<>(); for (TimetableEntry e: entries) timetable.add(Map.of("entryId",e.getEntryId(),"roomNo",Objects.toString(e.getLhNo(),""),"subject",Objects.toString(e.getSubjectName(),""),"section",Objects.toString(e.getSectionName(),""),"startTime",e.getStartTime().toString(),"endTime",e.getEndTime().toString()));
        LocalDate reportDate = nextOccurrence(DayOfWeek.valueOf(selected));
        List<Map<String,Object>> bookings = new ArrayList<>();
        for (Booking b: bookingRepository.findByBookingDateAndStatusIgnoreCase(reportDate,"CONFIRMED")) bookings.add(Map.of("bookingId",b.getBookingId(),"date",b.getBookingDate().toString(),"roomNo",Objects.toString(b.getRoomNo(),""),"startTime",b.getStartTime().toString(),"endTime",b.getEndTime().toString(),"purpose",Objects.toString(b.getPurpose(),""),"bookedBy",Objects.toString(b.getBookedBy(),"")));
        bookings.sort(Comparator.comparing((Map<String,Object> m)->m.get("startTime").toString()));
        return ResponseEntity.ok(Map.of("success",true,"day",selected,"reportDate",reportDate.toString(),"timetable",timetable,"bookings",bookings,"bookingCount",bookings.size(),"timetableCount",timetable.size()));
    }

    @GetMapping("/export")
    public ResponseEntity<byte[]> export(@RequestParam(required=false) String academicYear,@RequestParam(required=false) Integer semesterNo,@RequestParam(required=false) String sectionName) throws IOException {
        List<TimetableEntry> entries=filteredEntries(academicYear,semesterNo,sectionName); Map<String,Integer> dayCounts=new LinkedHashMap<>(); DAYS.forEach(d->dayCounts.put(d,0)); Map<String,Integer> roomCounts=new HashMap<>();
        for(TimetableEntry e:entries){dayCounts.computeIfPresent(e.getDayOfWeek(),(k,v)->v+1);roomCounts.merge(e.getLhNo(),1,Integer::sum);} LocalDate today=LocalDate.now(); long bookingsToday=bookingRepository.findByBookingDateAndStatusIgnoreCase(today,"CONFIRMED").size();
        try(Workbook wb=new XSSFWorkbook();ByteArrayOutputStream out=new ByteArrayOutputStream()){CellStyle head=wb.createCellStyle();Font f=wb.createFont();f.setBold(true);head.setFont(f);Sheet s=wb.createSheet("Summary");String[][] rows={{"GNITS Smart Campus Operations Report",""},{"Academic Year",academicYear==null?"All":academicYear},{"Semester",semesterNo==null?"All":String.valueOf(semesterNo)},{"Section",sectionName==null||sectionName.isBlank()?"All":sectionName},{"Scheduled Slots (filtered)",String.valueOf(entries.size())},{"Scheduled Today",String.valueOf(entries.stream().filter(e->today.getDayOfWeek().name().equals(e.getDayOfWeek())).count())},{"Bookings Today",String.valueOf(bookingsToday)}};for(int r=0;r<rows.length;r++){Row row=s.createRow(r);row.createCell(0).setCellValue(rows[r][0]);row.createCell(1).setCellValue(rows[r][1]);if(r==0)row.getCell(0).setCellStyle(head);}Sheet day=wb.createSheet("Day Summary");Row h=day.createRow(0);h.createCell(0).setCellValue("Day");h.createCell(1).setCellValue("Scheduled Slots");h.getCell(0).setCellStyle(head);h.getCell(1).setCellStyle(head);int rr=1;for(var e:dayCounts.entrySet()){Row row=day.createRow(rr++);row.createCell(0).setCellValue(e.getKey());row.createCell(1).setCellValue(e.getValue());}Sheet room=wb.createSheet("Room Activity");h=room.createRow(0);h.createCell(0).setCellValue("Room");h.createCell(1).setCellValue("Scheduled Slots");h.getCell(0).setCellStyle(head);h.getCell(1).setCellStyle(head);rr=1;for(var e:roomCounts.entrySet().stream().sorted(Map.Entry.<String,Integer>comparingByValue().reversed()).toList()){Row row=room.createRow(rr++);row.createCell(0).setCellValue(e.getKey());row.createCell(1).setCellValue(e.getValue());}for(Sheet sh:new Sheet[]{s,day,room}){sh.autoSizeColumn(0);sh.autoSizeColumn(1);}wb.write(out);return ResponseEntity.ok().header("Content-Disposition","attachment; filename=\"GNITS_Campus_Operations_Report.xlsx\"").header("Content-Type","application/vnd.openxmlformats-officedocument.spreadsheetml.sheet").body(out.toByteArray());}
    }

    private List<TimetableEntry> filteredEntries(String year,Integer sem,String section){return timetableRepository.findAll().stream().filter(e->year==null||year.isBlank()||year.equalsIgnoreCase(e.getAcademicYear())).filter(e->sem==null||Objects.equals(sem,e.getSemesterNo())).filter(e->section==null||section.isBlank()||section.equalsIgnoreCase(e.getSectionName())).toList();}
    private static boolean roomMatches(TimetableEntry entry, Room room) {
        if (entry.getRoomId() != null && Objects.equals(entry.getRoomId(), room.getRoomId())) return true;
        return normalizeRoom(entry.getLhNo()).equals(normalizeRoom(room.getRoomNo()));
    }
    private static String normalizeRoom(String value) {
        if (value == null) return "";
        return value.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
    }
    private static boolean isSpecial(String s){return "MAINTENANCE".equalsIgnoreCase(s)||"RESERVED".equalsIgnoreCase(s);}
    private static boolean overlaps(LocalTime check,LocalTime start,LocalTime end){return !check.isBefore(start)&&check.isBefore(end);}
    private static LocalDate nextOccurrence(DayOfWeek target){LocalDate now=LocalDate.now();int delta=(target.getValue()-now.getDayOfWeek().getValue()+7)%7;return now.plusDays(delta);}
}
