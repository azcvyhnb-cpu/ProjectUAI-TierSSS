-- Thai helper text for the in-game UI. Control names and identifiers stay English.
-- This is presentation-only: tool schemas and model-facing descriptions are untouched.
return function(_env)
	local M = {}

	local TEXT = {
		["Layout follows the viewport by default. Pin it if you would rather it did not."] = "หน้าต่างจะปรับตามขนาดหน้าจออัตโนมัติ หากไม่ต้องการให้ปรับตามจอ ให้เลือกการจัดวางแบบคงที่",
		["Quick chat opens in the middle of the screen, takes one message to the conversation the Chat panel shows, and closes itself."] = "Quick chat เปิดหน้าต่างพิมพ์ด่วนกลางจอ ส่งข้อความเข้าแชตปัจจุบัน แล้วปิดตัวเอง",
		["This client has no telemetry and no home to call. The provider you choose is the only service that receives your conversation."] = "ตัวโปรแกรมไม่ส่งข้อมูลการใช้งานกลับบ้าน ข้อความจะส่งไปยังผู้ให้บริการ AI ที่คุณเลือกเท่านั้น",
		["Keys and logs"] = "ตั้งค่าคีย์และบันทึกการทำงาน",
		["Clear what is stored"] = "ลบข้อมูลที่บันทึกไว้",
		["This session"] = "เซสชันนี้",
		["Everything recorded"] = "สถิติทั้งหมดที่บันทึกไว้",
		["Which model spent what."] = "ดูว่าแต่ละโมเดลใช้โทเคนและค่าใช้จ่ายเท่าไร",
		["Across every conversation."] = "รวมข้อมูลจากทุกบทสนทนา",
		["The greeting and the counters an empty conversation opens with."] = "การ์ดต้อนรับและสถิติที่แสดงเมื่อเปิดบทสนทนาใหม่",
		["The agent hands self-contained work to a subagent with dispatch_agent: its own context, a subset of the tools, and a written report at the end. Everything dispatched in this session is here, whichever conversation started it."] = "AI สามารถแบ่งงานให้ AI ย่อยทำแยกกัน โดยแต่ละตัวมีบริบทและชุดเครื่องมือของตัวเอง พร้อมส่งรายงานเมื่อเสร็จ งานที่สั่งทั้งหมดในเซสชันนี้จะแสดงที่นี่",
		["When the agent delegates -- a wide search, a sweep of the instance tree, or a second opinion -- each child runs with its own context and returns a report."] = "เมื่อ AI แบ่งงาน เช่น ค้นหาข้อมูลจำนวนมาก สำรวจโครงสร้าง Instance หรือขอความเห็นอีกชุด งานย่อยจะทำงานแยกบริบทและส่งรายงานกลับมา",
		["Give your conversation more room in the browser. Follow the steps below on this computer. "] = "เปิดบทสนทนาในเบราว์เซอร์เพื่อให้มีพื้นที่ทำงานมากขึ้น ทำตามขั้นตอนด้านล่างบนอุปกรณ์นี้",
		["Select a request or log entry to inspect its details."] = "เลือกคำขอหรือรายการบันทึก เพื่อดูรายละเอียด เช่น สถานะ เวลา และข้อผิดพลาด",
		["Requests appear here with status, duration and transport details after you send a message."] = "หลังส่งข้อความ คำขอที่เกิดขึ้นจะแสดงที่นี่ พร้อมสถานะ ระยะเวลา และรายละเอียดการเชื่อมต่อ",
		["Application events will appear here as they occur."] = "เหตุการณ์ของโปรแกรมจะแสดงที่นี่เมื่อเกิดขึ้น",
		["Search by a tool name or what you want it to do."] = "ค้นหาด้วยชื่อเครื่องมือ หรือพิมพ์สิ่งที่ต้องการให้ AI ทำ",
		["Search tools"] = "ค้นหาเครื่องมือ",
		["No matching tools"] = "ไม่พบเครื่องมือที่ตรงกัน",
		["everything is available"] = "เครื่องมือทั้งหมดพร้อมใช้งาน",
		["not offered to the model"] = "จะไม่แสดงเครื่องมือนี้ให้ AI เลือกใช้",
		["Parameters & permissions"] = "ดูพารามิเตอร์และสิทธิ์",
		["Hide details"] = "ซ่อนรายละเอียด",
		["Default"] = "ค่าเริ่มต้น",
		["Allow"] = "อนุญาต",
		["Ask"] = "ถามก่อนอนุญาต",
		["Deny"] = "ปฏิเสธ",
		["Appearance"] = "รูปลักษณ์",
		["Shortcuts"] = "ปุ่มลัด",
		["Where your data goes"] = "ข้อมูลของคุณถูกส่งไปที่ไหน",
		["Code appearance"] = "รูปลักษณ์ของโค้ด",
		["Full configuration"] = "การตั้งค่าทั้งหมด",
		["Diagnostic export"] = "ส่งออกข้อมูลวิเคราะห์ปัญหา",
		["Import"] = "นำเข้า",
		["Window"] = "หน้าต่าง",
		["Comfortable"] = "โปร่ง อ่านง่าย",
		["Compact"] = "กะทัดรัด",
		["Auto"] = "อัตโนมัติ",
		["Sheet"] = "แผ่นหน้าต่าง",
		["Panel"] = "แผง",
		["Reduce motion"] = "ลดภาพเคลื่อนไหว",
		["Show reasoning"] = "แสดงเหตุผลที่ AI ส่งมา",
		["Show the code a tool was given"] = "แสดงโค้ดหรือข้อมูลที่ส่งให้เครื่องมือ",
		["Expand tool detail"] = "เปิดรายละเอียดเครื่องมือไว้",
		["Show token counts"] = "แสดงจำนวนโทเคน",
		["Show the activity card"] = "แสดงการ์ดสรุปกิจกรรม",
		["Notify while minimized"] = "แจ้งเตือนเมื่อย่อหน้าต่าง",
		["Auto follows the platform's own accessibility preference."] = "โหมดอัตโนมัติจะใช้ค่าการช่วยการเข้าถึงของอุปกรณ์",
		["Display the model's chain of thought when it sends one. Applies to the conversation already on screen."] = "แสดงข้อความ reasoning เมื่อโมเดลส่งมา ใช้กับบทสนทนาที่เปิดอยู่",
		["Token and cost details in the composer's options menu."] = "แสดงจำนวนโทเคนและค่าใช้จ่ายในเมนูตัวเลือกของช่องพิมพ์",
		["The transcript and the model's context are both discarded."] = "ลบทั้งประวัติแชตและบริบทที่ AI ใช้อยู่",
		["Every transcript on disk is removed. The activity counters are kept."] = "ลบประวัติแชตทั้งหมดที่บันทึกไว้ แต่เก็บสถิติกิจกรรมไว้",
		["Paste the private JSON copied by Full configuration export. Review it before replacing your settings."] = "วาง JSON ที่ได้จาก Full configuration export ตรวจสอบค่าก่อนนำมาแทนที่การตั้งค่าปัจจุบัน",
		["A path inside "] = "ระบุพาธของไฟล์ภายในโฟลเดอร์ ",
		["What this client will actually send, and how the endpoint has "] = "ดูข้อมูลที่โปรแกรมจะส่งจริง และสถานะของปลายทางที่เชื่อมต่อ",
		["Only what the endpoint reported and what you added -- never a guess, "] = "แสดงเฉพาะโมเดลที่ปลายทางแจ้งหรือคุณเพิ่มเอง ไม่เดาชื่อโมเดลให้",
		["Per-provider switches. Each one can only narrow what the matching "] = "ตัวเลือกแยกตามผู้ให้บริการ ใช้จำกัดพฤติกรรมของผู้ให้บริการแต่ละราย",
		["Optional gateway streaming and extra headers, body fields and query parameters. "] = "ตั้งค่าการสตรีมผ่าน Gateway และเพิ่ม Headers, ฟิลด์ใน Body หรือพารามิเตอร์ใน URL",
		["Any endpoint that speaks /v1/chat/completions, or Anthropic's Messages API."] = "ใช้ปลายทางที่รองรับ /v1/chat/completions หรือ Messages API ของ Anthropic",
		["Type it exactly as the provider expects it. It is saved with this "] = "กรอกรหัสโมเดลให้ตรงตามที่ผู้ให้บริการกำหนด ระบบจะบันทึกไว้กับผู้ให้บริการนี้",
		["The endpoint and its key are deleted from this device. This cannot be undone."] = "ลบปลายทางและ API key ของรายการนี้ออกจากอุปกรณ์ การกระทำนี้ย้อนกลับไม่ได้",
		["Stops the current turn, drains every timer and input handler, "] = "หยุดงาน AI ที่กำลังทำ และยกเลิกตัวจับเวลาและตัวรับอินพุตที่เกี่ยวข้อง",
	}

	local PATTERNS = {
		{ "An API key is stored in the settings file", "API key จะถูกเก็บไว้ในไฟล์ตั้งค่า ส่วนบันทึกคำขอและไฟล์วิเคราะห์ปัญหาจะแสดงคีย์เพียง 4 ตัวท้าย" },
		{ "Each of these is immediate and cannot be undone.", "การดำเนินการแต่ละรายการมีผลทันทีและไม่สามารถย้อนกลับได้" },
		{ "What the client has spent since it started", "ค่าโทเคนและค่าใช้จ่ายตั้งแต่เปิดโปรแกรม โดยอิงข้อมูลที่ผู้ให้บริการรายงาน" },
		{ "Counted from what this client observed and kept on disk", "สถิติที่โปรแกรมเก็บไว้ในอุปกรณ์ จึงยังอยู่หลังปิดและเปิดใหม่" },
		{ "How a fenced code block is drawn", "กำหนดรูปแบบการแสดงบล็อกโค้ดในประวัติแชตและส่วนอื่น ๆ" },
		{ "The type the interface itself is set in.", "เลือกแบบอักษรที่ใช้กับข้อความในหน้าตาโปรแกรม" },
		{ "A browser on this machine can join the conversation", "เปิดบทสนทนานี้บนเบราว์เซอร์ของอุปกรณ์เดียวกันผ่าน Web bridge" },
		{ "Copy every saved setting to another device", "ส่งออกการตั้งค่าทั้งหมดเพื่อย้ายไปอุปกรณ์อื่น ไฟล์นี้มี API keys และข้อมูลลับ ควรเก็บเป็นส่วนตัว" },
		{ "Writes a copy of your settings and the activity history", "บันทึกสำเนาการตั้งค่าและประวัติกิจกรรมเพื่อใช้วิเคราะห์ปัญหา โดยปกปิด API key เหลือ 4 ตัวท้าย" },
		{ "Reads a file from the client's folder and applies the settings in it.", "อ่านไฟล์จากโฟลเดอร์ของโปรแกรมแล้วนำการตั้งค่าในไฟล์มาใช้ ตรวจสอบไฟล์ก่อนนำเข้า" },
		{ "Where the interface opens and how much of the screen it takes.", "กำหนดว่าเปิดหน้าต่างที่หน้าใด และใช้พื้นที่หน้าจอมากเท่าไร" },
		{ "What the client found when it started.", "ข้อมูลความสามารถที่ตรวจพบเมื่อเริ่มทำงาน ค่านี้เป็นข้อมูลอ่านอย่างเดียว" },
		{ "Every request and every log line the client has kept", "ดูคำขอที่ส่งออกและข้อความบันทึกที่โปรแกรมเก็บไว้ เพื่อวิเคราะห์ปัญหา" },
		{ "Requests are sent as the Claude Code CLI.", "กำหนดข้อมูลระบุตัวตนที่ส่งไปกับคำขอ สำหรับ Gateway ที่ตรวจสอบส่วนนี้" },
		{ "Providers, permission rules and memory are kept unless you say otherwise.", "ข้อมูลผู้ให้บริการ กฎสิทธิ์ และหน่วยความจำจะยังอยู่ เว้นแต่คุณเลือกให้ลบด้วย" },
		{ "How hard it works before it stops and answers.", "กำหนดจำนวนรอบที่ AI ใช้เรียกเครื่องมือก่อนหยุดและตอบกลับ" },
		{ "Added to the system prompt every turn", "เพิ่มคำสั่งเหล่านี้เข้าไปในคำสั่งระบบทุกครั้งที่ AI ทำงาน" },
		{ "A family of tools can be withheld from the model entirely.", "ปิดทั้งหมวดเพื่อไม่ให้ AI เห็นเครื่องมือในหมวดนั้น ต่างจากการปฏิเสธคำสั่งเฉพาะครั้ง" },
		{ "Facts the agent has chosen to keep between sessions.", "ข้อมูลที่ AI บันทึกไว้เพื่อใช้ข้ามเซสชัน สามารถอ่านและลบได้จากส่วนนี้" },
		{ "Where requests go. A provider is a base URL", "กำหนดปลายทาง API วิธีตรวจสอบสิทธิ์ คีย์ และโมเดลที่จะรับคำขอ" },
		{ "The one connector that is not a model", "เชื่อมต่อบทสนทนากับเบราว์เซอร์ผ่านโปรแกรม bridge ในอุปกรณ์นี้" },
		{ "Run Infinite Yield inside this client", "เปิดใช้คำสั่ง Infinite Yield ให้ AI เรียกผ่านเครื่องมือ iy ที่รองรับ" },
		{ "Tool rounds allowed in one turn", "จำนวนรอบการเรียกเครื่องมือที่อนุญาตในหนึ่งคำตอบ" },
		{ "Quick chat opens in the middle of the screen", "เปิด Quick chat กลางจอ ส่งข้อความเข้าแชตที่เปิดอยู่ แล้วปิดหน้าต่างเอง" },
		{ "Draws the Luau, the file body or the property map", "แสดงโค้ด Luau เนื้อหาไฟล์ หรือแผนที่คุณสมบัติที่ส่งให้เครื่องมือใต้รายการเรียกใช้" },
		{ "Open the remaining arguments and the result by default", "เปิดรายละเอียดพารามิเตอร์และผลลัพธ์ของเครื่องมือไว้ตั้งแต่แรก" },
		{ "The greeting and the counters an empty conversation", "แสดงการ์ดต้อนรับและสถิติเมื่อเปิดบทสนทนาใหม่" },
		{ "A toast when a turn finishes", "แสดงการแจ้งเตือนเมื่อ AI ทำงานเสร็จ ล้มเหลว หรือถูกหยุด แม้ย่อหน้าต่างอยู่" },
		{ "Multiplies every type size.", "ปรับขนาดตัวอักษรทุกส่วนด้วยตัวคูณเดียวกัน" },
		{ "Press one to use it.", "แตะตัวเลือกแบบอักษรเพื่อเลือกใช้งาน" },
		{ "This client has no telemetry and no home to call.", "โปรแกรมไม่ส่งข้อมูลการใช้งานกลับบ้าน คำขอภายนอกมีเฉพาะปลายทางที่คุณเพิ่มไว้" },
	}

	local GROUPS = {
		agentself = "เครื่องมือสำหรับวิเคราะห์ วางแผน และจัดการงานของ AI",
		instance = "สำรวจและอ่านโครงสร้าง Instance ของเกม รวมถึงคุณสมบัติและลูกของแต่ละวัตถุ",
		script = "อ่านและจัดการสคริปต์หรือโค้ดในสภาพแวดล้อมที่รองรับ",
		coding = "สร้าง แก้ไข ค้นหา และจัดการไฟล์โค้ดใน Workspace ของโปรเจกต์",
		fs = "อ่าน เขียน ค้นหา และจัดการไฟล์ที่ระบบอนุญาตให้เข้าถึง",
		net = "ส่งคำขอ HTTP ไปยังบริการภายนอก เมื่อสภาพแวดล้อมรองรับ",
		web = "ค้นหาและอ่านข้อมูลจากเว็บผ่านเครื่องมือที่เชื่อมต่อไว้",
		players = "อ่านข้อมูลผู้เล่นที่เกมเปิดเผยให้สคริปต์เข้าถึง",
		character = "ตรวจสอบตัวละครและสถานะที่เกี่ยวข้อง",
		world = "ตรวจสอบวัตถุและสภาพแวดล้อมในโลกของเกม",
		remotes = "ตรวจสอบ RemoteEvent และ RemoteFunction ที่พบในเกม โปรดตรวจสอบสิทธิ์ก่อนใช้งาน",
		gui = "สำรวจองค์ประกอบหน้าจอและ GUI ที่เกมสร้างขึ้น",
		perf = "ตรวจสอบประสิทธิภาพ สถานะ และข้อมูลวิเคราะห์ปัญหา",
		meta = "อ่านข้อมูลสภาพแวดล้อมและความสามารถของระบบ",
		chat = "อ่านหรือส่งข้อความแชตในเกม เฉพาะเมื่อสภาพแวดล้อมอนุญาต",
		input = "จำลองอินพุตเสมือน เช่น ปุ่มหรือการคลิก เมื่อ executor รองรับ",
		templates = "ใช้แม่แบบสำเร็จรูปเพื่อทำงานที่พบบ่อยได้เร็วขึ้น",
		screen = "อ่านข้อมูลหน้าจอและเครื่องมือช่วยเล็งที่มีให้",
		iy = "เข้าถึงคำสั่งที่เกี่ยวข้องกับ Infinite Yield หากมีอยู่ในสภาพแวดล้อม",
		gravity = "เครื่องมือที่เกี่ยวข้องกับ Project Gravity",
		skills = "ค้นหาและใช้ความสามารถหรือชุดขั้นตอนที่เพิ่มเข้ามา",
	}

	local TOOL_TEXT = {
		get_place_info = "อ่านข้อมูลพื้นฐานของเกมหรือ Place ปัจจุบัน",
		get_game_info = "อ่านข้อมูลพื้นฐานของเกมปัจจุบัน",
		get_players = "แสดงรายชื่อผู้เล่นและข้อมูลที่เข้าถึงได้",
		get_character = "อ่านข้อมูลตัวละครของผู้เล่น",
		get_workspace_tree = "สำรวจโครงสร้าง Workspace แบบเป็นลำดับชั้น",
		get_instance = "อ่านข้อมูลและคุณสมบัติของ Instance ที่ระบุ",
		find_instances = "ค้นหา Instance ตามชื่อหรือเงื่อนไข",
		get_remote_list = "ค้นหารายการ Remote ที่ตรวจพบ",
		get_remote_info = "อ่านรายละเอียดของ Remote ที่เลือก",
		capture_remote = "บันทึกข้อมูลการเรียก Remote เพื่อใช้ตรวจสอบ",
		get_screen = "อ่านข้อมูลหน้าจอที่เครื่องมือรองรับ",
		get_logs = "อ่านบันทึกการทำงานเพื่อช่วยวิเคราะห์ปัญหา",
		get_performance = "ตรวจสอบข้อมูลประสิทธิภาพของเกมหรือสคริปต์",
		web_search = "ค้นหาข้อมูลจากเว็บตามคำค้น",
		web_fetch = "เปิดอ่านเนื้อหาจาก URL ที่ระบุ",
		research_search = "ค้นหาบันทึกความรู้ที่เคยบันทึกไว้สำหรับเกมนี้",
		research_save = "บันทึกข้อค้นพบเพื่อให้ AI เรียกใช้ในครั้งต่อไป",
		research_list = "แสดงรายการบันทึกความรู้ที่เก็บไว้",
		research_get = "เปิดอ่านบันทึกความรู้รายการที่ระบุ",
	}

	function M.text(value)
		if type(value) ~= "string" then return value end
		if TEXT[value] then return TEXT[value] end
		for _, pattern in ipairs(PATTERNS) do
			if value:find(pattern[1], 1, true) then return pattern[2] end
		end
		return value
	end

	function M.group(group)
		return GROUPS[group] or "เครื่องมือในหมวดนี้ใช้ทำงานกับส่วนที่ระบุไว้ ชื่อเครื่องมือบอกการกระทำเฉพาะเจาะจง"
	end

	function M.tool(tool)
		if type(tool) ~= "table" then return "" end
		if TOOL_TEXT[tool.name] then return TOOL_TEXT[tool.name] end
		return M.group(tool.group)
	end

	return M
end
