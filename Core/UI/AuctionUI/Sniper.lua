-- ------------------------------------------------------------------------------ --
--                                TradeSkillMaster                                --
--                http://www.curse.com/addons/wow/tradeskill-master               --
--                                                                                --
--             A TradeSkillMaster Addon (http://tradeskillmaster.com)             --
--    All Rights Reserved* - Detailed license information included with addon.    --
-- ------------------------------------------------------------------------------ --

local _, TSM = ...
local Sniper = TSM.UI.AuctionUI:NewPackage("Sniper")
local L = TSM.L
local private = { fsm = nil, selectionFrame = nil, hasLastScan = nil, contentPath = "selection" }
-- TOX: 超过60秒没反应就重置AH
local PHASED_TIME = 60

-- ============================================================================
-- TOX:
-- 默认实现：
-- 		首先进行无限循环搜索，并把结果记录下来，点击单条记录后必定再执行一次搜索
-- 增强实现：
--   1. 增加动态黑名单功能，使用不含有卖家的hash作为key
--   2. 每次扫描完成之后，如果有结果并且不在黑名单上就自动选择一项，如果没有结果，默认自动重搜
--   3. 点击继续之后会取消当前选择，并且将当前的所有条目加入黑名单，然后启动狙击
--   4. 点击条目之后，首先判断当前选择是否在拍卖行列表里，如果不在列表里，则启动一个单独搜索
--   5. 视觉上高亮选中的项目，灰色非当前的搜索结果
--   6. 对于在拍卖行列表中的物品，在最右侧增加直接购买的按钮
-- ============================================================================

-- ============================================================================
-- Module Functions
-- ============================================================================

function Sniper.OnInitialize()
	TSM.UI.AuctionUI.RegisterTopLevelPage(L["Sniper"], "iconPack.24x24/Sniper", private.GetSniperFrame, private.OnItemLinked)
	private.FSMCreate()
end



-- ============================================================================
-- Sniper UI
-- ============================================================================

function private.GetSniperFrame()
	TSM.UI.AnalyticsRecordPathChange("auction", "sniper")
	if not private.hasLastScan then
		private.contentPath = "selection"
	end
	return TSMAPI_FOUR.UI.NewElement("ViewContainer", "sniper")
		:SetNavCallback(private.GetSniperContentFrame)
		:AddPath("selection")
		:AddPath("scan")
		:SetPath(private.contentPath)
end

function private.GetSniperContentFrame(viewContainer, path)
	private.contentPath = path
	if path == "selection" then
		return private.GetSelectionFrame()
	elseif path == "scan" then
		return private.GetScanFrame()
	else
		error("Unexpected path: "..tostring(path))
	end
end

function private.GetSelectionFrame()
	TSM.UI.AnalyticsRecordPathChange("auction", "sniper", "selection")
	local frame = TSMAPI_FOUR.UI.NewElement("Frame", "selection")
		:SetLayout("VERTICAL")
		:SetStyle("background", "#272727")
		:SetStyle("padding", { top = 38 })
		:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "buttons")
			:SetLayout("HORIZONTAL")
			:SetStyle("height", 26)
			:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "leftSpacer"))
			:AddChild(TSMAPI_FOUR.UI.NewElement("ActionButton", "buyoutScanBtn")
				:SetStyle("margin", { right = 24 })
				:SetStyle("width", 200)
				:SetText(L["Run Buyout Sniper"])
				:SetScript("OnClick", private.BuyoutScanButtonOnClick)
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("ActionButton", "bidScanBtn")
				:SetStyle("width", 200)
				:SetText(L["Run Bid Sniper"])
				:SetScript("OnClick", private.BidScanButtonOnClick)
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "rightSpacer"))
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("Texture", "line")
			:SetStyle("margin", { top = 16 })
			:SetStyle("height", 2)
			:SetStyle("color", "#9d9d9d")
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("SniperScrollingTable", "auctions")
		)
		:AddChildNoLayout(TSMAPI_FOUR.UI.NewElement("Text", "text")
			:SetStyle("relativeLevel", 2)
			:SetStyle("anchors", { { "LEFT", "auctions" }, { "RIGHT", "auctions" } })
			:SetStyle("height", 20)
			:SetStyle("font", TSM.UI.Fonts.MontserratMedium)
			:SetStyle("fontHeight", 14)
			:SetStyle("justifyH", "CENTER")
			:SetStyle("textColor", "#ffffff")
			:SetText(L["Start either a 'Buyout' or 'Bid' sniper using the buttons above."])
		)
		:SetScript("OnUpdate", private.SelectionFrameOnUpdate)
		:SetScript("OnHide", private.SelectionFrameOnHide)
	private.selectionFrame = frame
	return frame
end

function private.GetScanFrame()
	TSM.UI.AnalyticsRecordPathChange("auction", "sniper", "scan")
	return TSMAPI_FOUR.UI.NewElement("Frame", "scan")
		:SetLayout("VERTICAL")
		:SetStyle("background", "#272727")
		:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "header")
			:SetLayout("HORIZONTAL")
			:SetStyle("height", 79)
			:SetStyle("padding", { left = 16, right = 16, top = 37, bottom = 14 })
			:AddChild(TSMAPI_FOUR.UI.NewElement("Button", "cancelBtn")
				:SetStyle("width", 100)
				:SetStyle("font", TSM.UI.Fonts.MontserratMedium)
				:SetStyle("fontHeight", 14)
				:SetStyle("textColor", "#ffffff")
				:SetText(L["Stop Scan"])
				:SetScript("OnClick", private.CancelButtonOnClick)
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("Text", "title")
				:SetStyle("font", TSM.UI.Fonts.MontserratMedium)
				:SetStyle("fontHeight", 20)
				:SetStyle("justifyH", "CENTER")
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("Spacer", "spacer")
				:SetStyle("width", 100)
			)
			:AddChildNoLayout(TSMAPI_FOUR.UI.NewElement("Button", "resumeBtn")
				:SetStyle("anchors", { { "TOPLEFT", nil, "TOPRIGHT", -116, -37 }, { "BOTTOMRIGHT", -16, 14 } })
				:SetStyle("font", TSM.UI.Fonts.MontserratMedium)
				:SetStyle("fontHeight", 14)
				:SetStyle("textColor", "#ffffff")
				:SetText(L["Resume Scan"])
				:SetScript("OnClick", private.ResumeButtonOnClick)
			)
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("Texture", "line")
			:SetStyle("height", 2)
			:SetStyle("color", "#9d9d9d")
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("SniperScrollingTable", "auctions")
			:SetScript("OnSelectionChanged", private.AuctionsOnSelectionChanged)
			:SetScript("OnRowRemoved", private.AuctionsOnRowRemoved)
		)
		:AddChild(TSMAPI_FOUR.UI.NewElement("Frame", "bottom")
			:SetLayout("HORIZONTAL")
			:SetStyle("height", 38)
			:SetStyle("padding.bottom", -2)
			:SetStyle("padding.top", 6)
			:SetStyle("background", "#363636")
			:AddChild(TSMAPI_FOUR.UI.NewElement("ProgressBar", "progressBar")
				:SetStyle("margin.right", 8)
				:SetStyle("height", 28)
				:SetProgress(0)
				:SetText(L["Starting Scan..."])
			)
			:AddChild(TSMAPI_FOUR.UI.NewNamedElement("ActionButton", "actionBtn", "TSMSniperBtn")
				:SetStyle("width", 135)
				:SetStyle("height", 26)
				:SetStyle("margin.right", 8)
				:SetStyle("iconTexturePack", "iconPack.14x14/Post")
				:SetText(strupper(BID))
				:SetDisabled(true)
				:DisableClickCooldown(true)
				:SetScript("OnClick", private.ActionButtonOnClick)
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("ActionButton", "skipBtn")
				:SetStyle("width", 135)
				:SetStyle("height", 26)
				:SetStyle("margin.right", 8)
				:SetStyle("iconTexturePack", "iconPack.14x14/Skip")
				:SetText(L["SKIP"])
				:SetDisabled(false)
				:DisableClickCooldown(true)
				:SetScript("OnClick", private.SkipButtonOnClick)
			)
			:AddChild(TSMAPI_FOUR.UI.NewElement("ActionButton", "restartBtn")
				:SetStyle("width", 135)
				:SetStyle("height", 26)
				:SetStyle("iconTexturePack", "iconPack.14x14/Reset")
				:SetText(L["RESTART"])
				:SetScript("OnClick", private.RestartButtonOnClick)
			)
		)
		:SetScript("OnUpdate", private.ScanFrameOnUpdate)
		:SetScript("OnHide", private.ScanFrameOnHide)
end



-- ============================================================================
-- Local Script Handlers
-- ============================================================================

function private.OnItemLinked(name, itemLink)
	if private.selectionFrame then
		return false
	end
	private.fsm:ProcessEvent("EV_STOP_CLICKED")
	TSM.UI.AuctionUI.SetOpenPage(L["Shopping"])
	TSM.UI.AuctionUI.Shopping.StartItemSearch(itemLink)
	return true
end

function private.SelectionFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	frame:GetBaseElement():SetBottomPadding(nil)
end

function private.SelectionFrameOnHide(frame)
	assert(frame == private.selectionFrame)
	private.selectionFrame = nil
end

function private.ScanOnFilterDone(self, filter, numNewResults)
	-- 这里的 self 是 scanFrame
	if numNewResults > 0 then
		TSM.Sound.PlaySound(TSM.db.global.sniperOptions.sniperSound)
		print("找到", numNewResults, "件物品，暂停搜索")
		-- TOX: 有结果，暂停查找，等待用户操作，任何用户操作都可以终止
		private.fsm:ProcessEvent("EV_SCAN_PAUSE")
	else
		-- TOX: 搜索结果为空，自动重搜
		print("未找到任何物品，继续搜索")
		private.fsm:ProcessEvent("EV_SCAN_CONTINUE")
	end
end

function private.BuyoutScanButtonOnClick(button)
	if not TSM.UI.AuctionUI.StartingScan(L["Sniper"]) then
		return
	end
	button:GetParentElement():GetParentElement():GetParentElement():SetPath("scan", true)
	local threadId, marketValueFunc = TSM.Sniper.BuyoutSearch.GetScanContext()
	private.fsm:ProcessEvent("EV_START_SCAN", threadId, marketValueFunc, "buyout")
end

function private.BidScanButtonOnClick(button)
	if not TSM.UI.AuctionUI.StartingScan(L["Sniper"]) then
		return
	end
	button:GetParentElement():GetParentElement():GetParentElement():SetPath("scan", true)
	local threadId, marketValueFunc = TSM.Sniper.BidSearch.GetScanContext()
	private.fsm:ProcessEvent("EV_START_SCAN", threadId, marketValueFunc, "bid")
end

function private.AuctionsOnSelectionChanged()
	private.fsm:ProcessEvent("EV_AUCTION_SELECTION_CHANGED")
end

function private.AuctionsOnRowRemoved(_, row)
	private.fsm:ProcessEvent("EV_AUCTION_ROW_REMOVED", row)
end

function private.CancelButtonOnClick()
	private.fsm:ProcessEvent("EV_STOP_CLICKED")
end

function private.ResumeButtonOnClick(button)
	if not TSM.UI.AuctionUI.StartingScan(L["Sniper"]) then
		return
	end
	button:GetElement("__parent.__parent.auctions"):SetSelection(nil)
end

function private.ActionButtonOnClick(button)
	private.fsm:ProcessEvent("EV_ACTION_CLICKED")
end

function private.SkipButtonOnClick(button)
	private.fsm:ProcessEvent("EV_SKIP_CLICKED")
end

function private.RestartButtonOnClick(button)
	if not TSM.UI.AuctionUI.StartingScan(L["Sniper"]) then
		return
	end
	local lastScanType = private.hasLastScan
	local sniperFrame = button:GetParentElement():GetParentElement():GetParentElement()
	private.fsm:ProcessEvent("EV_STOP_CLICKED")
	if lastScanType == "bid" then
		sniperFrame:GetElement("selection.buttons.bidScanBtn"):Click()
	elseif lastScanType == "buyout" then
		sniperFrame:GetElement("selection.buttons.buyoutScanBtn"):Click()
	else
		error("Invalid last scan type: "..tostring(lastScanType))
	end
end

function private.ScanFrameOnUpdate(frame)
	frame:SetScript("OnUpdate", nil)
	frame:GetBaseElement():SetBottomPadding(38)
	private.fsm:ProcessEvent("EV_SCAN_FRAME_SHOWN", frame)
end

function private.ScanFrameOnHide(frame)
	private.fsm:ProcessEvent("EV_SCAN_FRAME_HIDDEN")
end



-- ============================================================================
-- FSM
-- ============================================================================

function private.FSMCreate()
	local fsmContext = {
		db = TSMAPI_FOUR.Auction.NewDatabase("SNIPER_AUCTIONS"),
		scanFrame = nil,
		scanType = nil,
		scanThreadId = nil,
		marketValueFunc = nil,
		auctionScan = nil,
		query = nil,
		progress = 0,
		progressText = L["Running Sniper Scan"],
		buttonsDisabled = true,
		findHash = nil,
		findAuction = nil,
		findResult = nil,
		numFound = 0,
		numActioned = 0,
		numConfirmed = 0,
	}
	TSM.Event.Register("CHAT_MSG_SYSTEM", private.FSMMessageEventHandler)
	TSM.Event.Register("UI_ERROR_MESSAGE", private.FSMMessageEventHandler)
	TSM.Event.Register("AUCTION_HOUSE_CLOSED", function()
		private.fsm:ProcessEvent("EV_AUCTION_HOUSE_CLOSED")
	end)
	local function UpdateScanFrame(context)
		if not context.scanFrame then
			return
		end
		local actionText = nil
		if context.scanType == "buyout" then
			actionText = strupper(BUYOUT)
		elseif context.scanType == "bid" then
			actionText = strupper(BID)
		else
			error("Invalid scanType: "..tostring(context.scanType))
		end
		local bottom = context.scanFrame:GetElement("bottom")
		bottom:GetElement("actionBtn")
			:SetText(actionText)
			:SetDisabled(context.buttonsDisabled)
		bottom:GetElement("progressBar")
			:SetProgress(context.progress)
			:SetText(context.progressText or "")
		local auctionList = context.scanFrame:GetElement("auctions")
			:SetContext(context.auctionScan)
			:SetQuery(context.query)
			:SetMarketValueFunction(context.marketValueFunc)
		if context.findAuction and not auctionList:GetSelectedRecord() then
			auctionList:SetSelectedRecord(context.findAuction)
		end
		local resumeBtn = context.scanFrame:GetElement("header.resumeBtn")
		local title = context.scanFrame:GetElement("header.title")
		if auctionList:GetSelectedRecord() then
			resumeBtn:SetDisabled(false)
			resumeBtn:Show()
			if context.scanType == "buyout" then
				title:SetText(L["Buyout Sniper Paused"])
			elseif context.scanType == "bid" then
				title:SetText(L["Bid Sniper Paused"])
			else
				error("Invalid scanType: "..tostring(context.scanType))
			end
		else
			resumeBtn:SetDisabled(true)
			resumeBtn:Hide()
			if context.scanType == "buyout" then
				title:SetText(L["Buyout Sniper Running"])
			elseif context.scanType == "bid" then
				title:SetText(L["Bid Sniper Running"])
			else
				error("Invalid scanType: "..tostring(context.scanType))
			end
		end
		context.scanFrame:Draw()
	end
	local function UpdateBuyButtons(context, selection)
		if not context.scanFrame then
			return
		end
		if selection and selection.seller == UnitName("player") then
			context.scanFrame:GetElement("bottom.actionBtn"):SetDisabled(true)
				:Draw()
		elseif selection and selection.isHighBidder then
			if context.scanType == "buyout" then
				context.scanFrame:GetElement("bottom.actionBtn"):SetDisabled(false)
					:Draw()
			else
				context.scanFrame:GetElement("bottom.actionBtn"):SetDisabled(true)
					:Draw()
			end
		else
			context.scanFrame:GetElement("bottom.actionBtn"):SetDisabled(false)
				:Draw()
		end
	end
	private.fsm = TSMAPI_FOUR.FSM.New("SNIPER")
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_INIT")
			:SetOnEnter(function(context, ...)
				private.hasLastScan = nil
				context.db:Truncate()
				if context.scanThreadId then
					TSMAPI_FOUR.Thread.Kill(context.scanThreadId)
					context.scanThreadId = nil
				end
				if context.query then
					context.query:Release()
					context.query = nil
				end
				context.marketValueFunc = nil
				context.progress = 0
				context.progressText = L["Running Sniper Scan"]
				context.buttonsDisabled = true
				context.findHash = nil
				context.findAuction = nil
				context.findResult = nil
				context.numFound = 0
				context.numActioned = 0
				context.numConfirmed = 0
				if context.auctionScan then
					context.auctionScan:Release()
					context.auctionScan = nil
				end
				if ... then
					local scanThreadId, marketValueFunc, scanType = ...
					context.scanThreadId = scanThreadId
					context.marketValueFunc = marketValueFunc
					context.scanType = scanType
					return "ST_RUNNING_SCAN"
				elseif context.scanFrame then
					context.scanFrame:GetParentElement():SetPath("selection", true)
					context.scanFrame = nil
				end
				TSM.UI.AuctionUI.EndedScan(L["Sniper"])
			end)
			:AddTransition("ST_INIT")
			:AddTransition("ST_RUNNING_SCAN")
			:AddEvent("EV_START_SCAN", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_INIT"))
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_RUNNING_SCAN")
			:SetOnEnter(function(context)
				private.hasLastScan = context.scanType
				if not context.query then
					context.query = context.db:NewQuery()
				end
				if not context.auctionScan then
					context.auctionScan = TSMAPI_FOUR.Auction.NewAuctionScan(context.db)
						:SetResolveSellers(false)
						:SetScript("OnFilterDone", private.ScanOnFilterDone)
				end
				if context.scanFrame then
					context.scanFrame:GetElement("bottom.progressBar"):SetProgressIconHidden(false)
				end
				UpdateScanFrame(context)
				TSMAPI_FOUR.Thread.SetCallback(context.scanThreadId, private.FSMScanCallback)
				TSMAPI_FOUR.Thread.Start(context.scanThreadId, context.auctionScan)
				TSMAPI_FOUR.Delay.AfterTime("sniperPhaseDetect", PHASED_TIME, private.FSMPhasedCallback)
			end)
			:SetOnExit(function(context)
				TSMAPI_FOUR.Delay.Cancel("sniperPhaseDetect")
			end)
			:AddTransition("ST_RESULTS")
			:AddTransition("ST_FINDING_AUCTION")
			:AddTransition("ST_SELECT_AUCTION")
			:AddTransition("ST_INIT")
			:AddEvent("EV_SCAN_COMPLETE", function(context)
				if context.scanFrame and context.scanFrame:GetElement("auctions"):GetSelectedRecord() then
					-- print("CONTINUE SCAN")
					return "ST_FINDING_AUCTION"
				else
					-- TOX: 将重搜功能移动到 FilterComplete 阶段
					-- return "ST_RESULTS"
					-- print("PAUSE")
				end
			end)
			:AddEvent("EV_SCAN_PAUSE", function(context)
				-- print("inside EV_SCAN_PAUSE")
				return "ST_SELECT_AUCTION"
			end)
			:AddEvent("EV_SCAN_CONTINUE", function(context)
				-- print("inside EV_SCAN_CONTINUE")
				return "ST_RESULTS"
			end)
			:AddEvent("EV_SCAN_FAILED", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_INIT"))
			:AddEvent("EV_PHASED", function()
				TSM:Print(L["You've been phased which has caused the AH to stop working due to a bug on Blizzard's end. Please close and reopen the AH and restart Sniper."])
				return "ST_INIT"
			end)
			:AddEvent("EV_AUCTION_SELECTION_CHANGED", function(context)
				assert(context.scanFrame)
				if context.scanFrame:GetElement("auctions"):GetSelectedRecord() then
					-- the user selected something, so cancel the current scan
					context.auctionScan:Cancel()
				end
			end)
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_RESULTS")
			:SetOnEnter(function(context)
				TSMAPI_FOUR.Thread.Kill(context.scanThreadId)
				-- find item
				context.findAuction = nil
				-- index for matching items in current list
				context.findResult = nil
				context.numFound = 0
				context.numActioned = 0
				context.numConfirmed = 0
				context.progress = 0
				context.progressText = L["Running Sniper Scan"]
				context.buttonsDisabled = true
				UpdateScanFrame(context)
				local selection = context.scanFrame and context.scanFrame:GetElement("auctions"):GetSelectedRecord()
				if selection then
					return "ST_FINDING_AUCTION"
				else
					return "ST_RUNNING_SCAN"
				end
			end)
			:AddTransition("ST_RUNNING_SCAN")
			:AddTransition("ST_AUCTION_FOUND")
			:AddTransition("ST_FINDING_AUCTION")
			:AddTransition("ST_INIT")
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_SELECT_AUCTION")
			:SetOnEnter(function(context)
				-- print("inside ST_SELECT_AUCTION")
				assert(context.scanFrame)
				local latest = context.scanFrame:GetElement("auctions"):GetLatestRecord()
				if latest then
					--- 自动选中一个物品
					print("当前选中物品:", latest:GetField("hash"))
					--- print("SET SELECTION", latest:GetField("hash"))
					context.scanFrame:GetElement("auctions"):SetSelectedRecord(latest)
				else
					print("没有符合条件的物品，继续搜索")
					return "ST_RESULTS"
				end
			end)
			:AddTransition("ST_RESULTS")
			:AddTransition("ST_FINDING_AUCTION")
		)
		--:AddState(TSMAPI_FOUR.FSM.NewState("ST_SELECT_AUCTION")
		--	:SetOnEnter(function(context)
		--		-- TODO: 增加 20 秒计时器，时间到了继续搜索
		--		-- print("inside ST_SELECT_AUCTION")
		--
		--		assert(context.scanFrame)
		--
		--		-- TOX: 从当前的搜索结果中自动选取一个物品
		--
		--		-- 当前的搜索结果
		--		local results = context.auctionScan:GetNewRecords()
		--
		--		assert(results)
		--
		--		-- find the best item from results
		--		local results = context.scanFrame:GetElement("auctions"):GetFiltersRecordIndex()
		--		local best = context.scanFrame:GetElement("auctions"):GetLatestRecord()
		--
		--		if best then
		--			--- 自动选中一个物品
		--			print("record.hashNoSeller =", best:GetField("hashNoSeller"))
		--			print("record.hash =", best:GetField("hash"))
		--
		--			--- update context
		--			context.findAuction = best
		--			context.findHash = best:GetField("hash")
		--			context.findResult = results
		--			context.findIndex = 0;
		--			context.numFound = context.auctionScan:GetNumCanBuy(context.findAuction) or math.huge
		--
		--			--- set selection
		--			-- 当 context.findAuction == latest 时 SetSelectedRecord 不会触发 ST_FINDING_AUCTION
		--			context.scanFrame:GetElement("auctions"):SetSelectedRecord(latest)
		--
		--			return "ST_BIDDING_BUYING"
		--		else
		--
		--			return "ST_RESULTS"
		--		end
		--	end)
		--	:AddTransition("ST_BIDDING_BUYING")
		--	:AddTransition("ST_RESULTS")
		--)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_FINDING_AUCTION")
			:SetOnEnter(function(context)
				assert(context.scanFrame)
				context.findAuction = context.scanFrame:GetElement("auctions"):GetSelectedRecord()
				context.findHash = context.findAuction:GetField("hash")
				context.progress = 0
				context.progressText = L["Finding Selected Auction"]
				context.buttonsDisabled = true
				if context.scanFrame then
					context.scanFrame:GetElement("bottom.progressBar"):SetProgressIconHidden(false)
				end
				UpdateScanFrame(context)
				TSM.Shopping.SearchCommon.StartFindAuction(context.auctionScan, context.findAuction, private.FSMFindAuctionCallback, true)
			end)
			:SetOnExit(function(context)
				TSM.Shopping.SearchCommon.StopFindAuction()
			end)
			:AddTransition("ST_RESULTS")
			:AddTransition("ST_FINDING_AUCTION")
			:AddTransition("ST_AUCTION_FOUND")
			:AddTransition("ST_AUCTION_NOT_FOUND")
			:AddTransition("ST_INIT")
			:AddEvent("EV_AUCTION_FOUND", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_AUCTION_FOUND"))
			:AddEvent("EV_AUCTION_NOT_FOUND", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_AUCTION_NOT_FOUND"))
			:AddEvent("EV_AUCTION_SELECTION_CHANGED", function(context)
				assert(context.scanFrame)
				if context.scanFrame:GetElement("auctions"):GetSelectedRecord() then
					return "ST_FINDING_AUCTION"
				else
					return "ST_RESULTS"
				end
				--local auctions = context.scanFrame:GetElement("auctions")
				--local selected = auctions:GetSelectedRecord()
				--if selected then
				--	-- find index for current selected item
				--	local index = auctions:GetRecordIndex(selected)
				--	if index then
				--		-- match current setup
				--		return
				--	else
				--		-- item is not in list, do a new search
				--		return "ST_FINDING_AUCTION"
				--	end
				--else
				--	-- dont select any thing, continue search
				--	return "ST_RESULTS"
				--end
			end)
			:AddEvent("EV_AUCTION_ROW_REMOVED", function(context, row)
				local removingFindAuction = context.findAuction == row
				context.auctionScan:DeleteRowFromDB(row)
				if removingFindAuction then
					return "ST_RESULTS"
				end
			end)
			:AddEvent("EV_SCAN_FRAME_HIDDEN", function(context)
				context.scanFrame = nil
				context.findAuction = nil
				return "ST_RESULTS"
			end)
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_AUCTION_FOUND")
			:SetOnEnter(function(context, result)
				context.findResult = result
				context.numFound = min(#result, context.auctionScan:GetNumCanBuy(context.findAuction) or math.huge)
				assert(context.numActioned == 0 and context.numConfirmed == 0)
				return "ST_BIDDING_BUYING"
			end)
			:AddTransition("ST_BIDDING_BUYING")
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_AUCTION_NOT_FOUND")
			:SetOnEnter(function(context)
				local link = context.findAuction:GetField("rawLink")
				context.auctionScan:DeleteRowFromDB(context.findAuction)
				TSM:Printf(L["Failed to find auction for %s, so removing it from the results."], link)
				return "ST_RESULTS"
			end)
			:AddTransition("ST_RESULTS")
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_BIDDING_BUYING")
			:SetOnEnter(function(context)
				print("inside ST_BIDDING_BUYING")
				local selection = context.scanFrame and context.scanFrame:GetElement("auctions"):GetSelectedRecord()
				local auctionSelected = selection and context.findHash == selection:GetField("hash")
				local numCanAction = not auctionSelected and 0 or (context.numFound - context.numActioned)
				local numConfirming = context.numActioned - context.numConfirmed
				local progressText = nil
				local actionFormatStr = nil
				if context.scanType == "buyout" then
					actionFormatStr = L["Buy %d / %d"]
				elseif context.scanType == "bid" then
					actionFormatStr = L["Bid %d / %d"]
				else
					error("Invalid scanType: "..tostring(context.scanType))
				end
				if numConfirming == 0 and numCanAction == 0 then
					-- we're done bidding/buying and confirming this batch
					return "ST_RESULTS"
				elseif numConfirming == 0 then
					-- we can still bid/buy more
					progressText = format(actionFormatStr, context.numActioned + 1, context.numFound)
				elseif numCanAction == 0 then
					-- we're just confirming
					progressText = format(L["Confirming %d / %d"], context.numConfirmed + 1, context.numFound)
				else
					-- we can bid/buy more while confirming
					progressText = format(actionFormatStr.." ("..L["Confirming %d / %d"]..")", context.numActioned + 1, context.numFound, context.numConfirmed + 1, context.numFound)
				end
				context.progress = context.numConfirmed / context.numFound
				context.progressText = L["Scan Paused"].." - "..progressText
				context.buttonsDisabled = numCanAction == 0
				if context.scanFrame then
					context.scanFrame:GetElement("bottom.progressBar"):SetProgressIconHidden(context.numConfirmed == context.numActioned)
				end
				UpdateBuyButtons(context, selection)
				UpdateScanFrame(context)
			end)
			:AddTransition("ST_BIDDING_BUYING")
			:AddTransition("ST_PLACING_BID_BUY")
			:AddTransition("ST_CONFIRMING_BID_BUY")
			:AddTransition("ST_RESULTS")
			:AddTransition("ST_INIT")
			:AddEvent("EV_AUCTION_SELECTION_CHANGED", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_RESULTS"))
			:AddEvent("EV_ACTION_CLICKED", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_PLACING_BID_BUY"))
			:AddEvent("EV_SKIP_CLICKED", function(context)
				-- print("INSIDE EV_SKIP_CLICKED")
				-- unselect to trigger scan
				context.scanFrame:GetElement("auctions"):SetSelection(nil)
			end)
			:AddEvent("EV_MSG", function(context, msg)
				if msg == LE_GAME_ERR_AUCTION_HIGHER_BID or msg == LE_GAME_ERR_ITEM_NOT_FOUND or msg == LE_GAME_ERR_AUCTION_BID_OWN or msg == LE_GAME_ERR_NOT_ENOUGH_MONEY then
					-- failed to bid/buy an auction
					return "ST_CONFIRMING_BID_BUY", false
				elseif context.scanType == "bid" and msg == ERR_AUCTION_BID_PLACED then
					-- bid on an auction
					return "ST_CONFIRMING_BID_BUY", true
				elseif context.scanType == "buyout" and msg == format(ERR_AUCTION_WON_S, context.findAuction:GetField("rawName")) then
					-- bought an auction
					return "ST_CONFIRMING_BID_BUY", true
				end
			end)
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_PLACING_BID_BUY")
			:SetOnEnter(function(context)
				-- get item from table
				local index = tremove(context.findResult, context.findIndex or #context.findResult)
				assert(index)
				if context.auctionScan:ValidateIndex(index, context.findAuction, true) then
					if context.scanType == "buyout" then
						-- buy the auction
						PlaceAuctionBid("list", index, context.findAuction:GetField("buyout"))
					elseif context.scanType == "bid" then
						-- bid on the auction
						PlaceAuctionBid("list", index, TSM.Auction.Util.GetRequiredBidByScanResultRow(context.findAuction))
					else
						error("Invalid scanType: "..tostring(context.scanType))
					end
					context.numActioned = context.numActioned + 1
				else
					if context.scanType == "buyout" then
						TSM:Printf(L["Failed to buy auction of %s (x%s) for %s."], context.findAuction:GetField("rawLink"), context.findAuction:GetField("stackSize"), TSM.Money.ToString(context.findAuction:GetField("buyout")))
					elseif context.scanType == "bid" then
						TSM:Printf(L["Failed to bid on auction of %s (x%s) for %s."], context.findAuction:GetField("rawLink"), context.findAuction:GetField("stackSize"), TSM.Money.ToString(context.findAuction:GetField("bid")))
					else
						error("Invalid scanType: "..tostring(context.scanType))
					end
				end
				return "ST_BIDDING_BUYING"
			end)
			:AddTransition("ST_BIDDING_BUYING")
		)
		:AddState(TSMAPI_FOUR.FSM.NewState("ST_CONFIRMING_BID_BUY")
			:SetOnEnter(function(context, success)
				if not success then
					TSM:Printf(L["Failed to buy auction of %s (x%s) for %s."], context.findAuction:GetField("rawLink"), context.findAuction:GetField("stackSize"), TSM.Money.ToString(context.findAuction:GetField("buyout")))
				end
				context.numConfirmed = context.numConfirmed + 1
				-- remove this row
				context.auctionScan:DeleteRowFromDB(context.findAuction, true)
				context.findAuction = context.scanFrame and context.scanFrame:GetElement("auctions"):GetSelectedRecord()
				return "ST_BIDDING_BUYING"
			end)
			:AddTransition("ST_BIDDING_BUYING")
		)
		:AddDefaultEvent("EV_SCAN_FRAME_SHOWN", function(context, scanFrame)
			context.scanFrame = scanFrame
			UpdateScanFrame(context)
		end)
		:AddDefaultEvent("EV_SCAN_FRAME_HIDDEN", function(context)
			context.scanFrame = nil
			context.findAuction = nil
		end)
		:AddDefaultEvent("EV_AUCTION_HOUSE_CLOSED", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_INIT"))
		:AddDefaultEvent("EV_STOP_CLICKED", TSMAPI_FOUR.FSM.SimpleTransitionEventHandler("ST_INIT"))
		:AddDefaultEvent("EV_AUCTION_ROW_REMOVED", function(context, row)
			context.auctionScan:DeleteRowFromDB(row)
		end)
		:Init("ST_INIT", fsmContext)
end

function private.FSMMessageEventHandler(_, msg)
	private.fsm:ProcessEvent("EV_MSG", msg)
end

function private.FSMScanCallback(success)
	if success then
		private.fsm:ProcessEvent("EV_SCAN_COMPLETE")
	else
		private.fsm:ProcessEvent("EV_SCAN_FAILED")
	end
end

function private.FSMPhasedCallback()
	private.fsm:ProcessEvent("EV_PHASED")
end

function private.FSMFindAuctionCallback(result)
	if result then
		private.fsm:ProcessEvent("EV_AUCTION_FOUND", result)
	else
		private.fsm:ProcessEvent("EV_AUCTION_NOT_FOUND")
	end
end
