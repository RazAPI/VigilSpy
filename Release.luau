--[[
	Filename.: Release.luau
	Description.: Object Activity Tracker
	Author.: lucibedroque \\ RazAPIx64 \\ RazAPIx64 \\ RazAPI \\ Raz
]]

local PrintConsole = function(Option, Message)
	assert(Option < 4, "No options above 3")

	local Options = {[1] = print, [2] = warn, [3] = error}
	if not Options[Option] then return "Invalid Option" end

	return Options[Option](Message)
end
--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
--// Globals
local RazAPI = {
	OldClosures = { type = type, typeof = typeof }, Environment = getgenv and getgenv() or getfenv(0), WhitelistedObjects = {},
	TypeCheck = function(Object, FunctionName, Type, Argument) assert(typeof(Object) == Type, `invalid argument #1 to {FunctionName}, expected {Type}, got {typeof(Object)}`) end, Connections = {}
}

RazAPI.WhitelistProxy = function(Object, WhitelistedTypeName)
	RazAPI.WhitelistedObjects[Object] = WhitelistedTypeName
end

RazAPI.SignConnection = function(Connection, Callback)
	return Connection:Connect(Callback)
end

Environment.type = function(Object)
	return RazAPI.WhitelistedObjects[Object] or RazAPI.OldClosures.type(Object)
end

Environment.typeof = function(Object)
	return RazAPI.WhitelistedObjects[Object] or RazAPI.OldClosures.typeof(Object)
end
--// GLH
local VigilSpyHelper = {
	PlayerLogs = { Joins = {}, Removed = {} },
	ObjectLogs = { Added = {}, Removed = {} },
	ObjectHelper = {},
	ObjectPropertyLogs = {
		Scripts = {},
		Interfaces = {},
		Remotes = {},
		Values = {},
		Services = {}
	},
	ObjectPropertyChangeLogs = {},
	Iteration = {}
}

--// sorry studio users
if RunService:IsStudio() then
	PrintConsole(2, "[ VigilSpy - Assistant ]: Cannot run in Studio due to capability restrictions. Error code 0x4F")
	return
end

if RazAPI.Environment.VigilConfiguration == nil then
	PrintConsole(2, "[ VigilSpy - Assistant ]: Could not find configuration, resetting factory settings (Error code 0x9C)")

	RazAPI.Environment.VigilConfiguration = {
		["TrackInstanceMethods"] = false
	}	
end

--// this will help track method calls
VigilSpyHelper.CreateUserSectionInstance = function(OriginalObject, Index, NewIndex)
	local Proxy = newproxy(true)
	local ProxyMt = getmetatable(Proxy)

	ProxyMt.__index = Index or function(_, Idx)
		return OriginalObject[Idx]
	end

	ProxyMt.__newindex = NewIndex or function(_, Idx, NewIdx)
		OriginalObject[Idx] = NewIdx
	end

	RazAPI.WhitelistProxy(Proxy, "Instance")
	return Proxy
end

VigilSpyHelper.CreateServiceProxy = function(OriginalObject)
	local Proxy = newproxy(true)
	local ProxyMt = getmetatable(Proxy)

	ProxyMt.__index = function(_, Idx)
		local Value = OriginalObject[Idx]

		if type(Value) == "function" then
			return function(self, ...)
				table.insert(VigilSpyHelper.ObjectPropertyChangeLogs, {
					Type = "MethodCall",
					Service = OriginalObject.ClassName,
					Method = Idx,
					Arguments = {...},
					Timestamp = os.clock()
				})

				PrintConsole(1, `[ VigilSpy - Method Called ]: {OriginalObject.ClassName}.{Idx}, Logs are sent to VigilSpyHelper.OPCL`)
				return Value(OriginalObject, ...)
			end
		end

		return Value
	end

	ProxyMt.__newindex = function(self, Idx, NewIdx)
		OriginalObject[Idx] = NewIdx
	end

	RazAPI.WhitelistProxy(Proxy, "Instance")
	return Proxy
end

local GetGenv = getgenv or getfenv(0)
local CloneRef = cloneref or function(Object) return VigilSpyHelper.CreateUserSectionInstance(Object) end
local GetInstances = getinstances or function() return game:GetDescendants() end
local GetNilInstances = getnilinstances or function() return {} end

local GetAllInstances = function()
	local Objects = {}

	for _, Value in GetInstances() do
		table.insert(Objects, Value)
	end

	for _, Value in GetNilInstances() do
		if not table.find(Objects, Value) then
			table.insert(Objects, Value)
		end
	end

	return Objects
end

local GetScripts = getscripts or function()
	local Scripts = {}

	for _, Value in GetInstances() do
		if Value:IsA("LuaSourceContainer") then
			table.insert(Scripts, Value)
		end
	end

	return Scripts
end

local GetProperties = getproperties or function() end
local GetHiddenProperty = gethiddenproperty or function(Object, Property) return pcall(Object, Property) end
local GetIdentity = getidentity or getthreadidentity or getthreadcontext or function()
	if RunService:IsStudio() then return "Studio" end
end

VigilSpyHelper.ObjectHelper.Filter = function(Properties)
	local Objects = {}

	for _, Value in GetAllInstances() do
		if Properties.ClassName == Value.ClassName then
			table.insert(Objects, Value)
		end
	end

	return Objects
end

VigilSpyHelper.ObjectHelper.FilterProxied = function(Properties)
	local Objects = {}

	for _, Value in GetAllInstances() do
		if Properties.ClassName == Value.ClassName then
			table.insert(Objects, VigilSpyHelper.CreateServiceProxy(Value))
		end
	end

	return Objects
end

RazAPI.SignConnection(Players.PlayerAdded, function(Player)
	table.insert(VigilSpyHelper.PlayerLogs.Joins, Player)
end)

RazAPI.SignConnection(Players.PlayerRemoving, function(Player)
	local Index = table.find(VigilSpyHelper.PlayerLogs.Joins, Player)

	if Index then
		table.remove(VigilSpyHelper.PlayerLogs.Joins, Index)
		table.insert(VigilSpyHelper.PlayerLogs.Removed, Player)
	end
end)

RazAPI.SignConnection(game.DescendantAdded, function(Object)
	table.insert(VigilSpyHelper.ObjectLogs.Added, Object)
end)

RazAPI.SignConnection(game.DescendantRemoving, function(Object)
	local Index = table.find(VigilSpyHelper.ObjectLogs.Added, Object)

	if Index then
		table.remove(VigilSpyHelper.ObjectLogs.Added, Index)
		table.insert(VigilSpyHelper.ObjectLogs.Removed, Object)
	end
end)

--// property watcher
VigilSpyHelper.Iteration.WatchInstanceProperties = function(Object, Properties, Category)
	RazAPI.TypeCheck(Object, "Instance", "WIPService", 1)

	local InstanceEntry = { Instance = Object, Category = Category, Changes = {} }
	table.insert(VigilSpyHelper.ObjectPropertyChangeLogs, InstanceEntry)

	for Index, Property in Properties do
		local Success, LastValue = pcall(function() return Object[Property] end)

		if not Success then
			continue
		end

		RazAPI.SignConnection(Object:GetPropertyChangedSignal(Property), function()
			local NewSuccess, NewValue = pcall(function() return Object[Property] end)
			if not NewSuccess then return end

			table.insert(InstanceEntry.Changes, {
				Property = Property,
				OldValue = LastValue,
				NewValue = NewValue,
				Timestamp = os.clock()
			})

			PrintConsole(1, `[ VigilSpy - Property Changed ]: {Object.Name}.{Property}: {LastValue} -> {NewValue}, Logs sent to VigilSypHelper.OPCL`)
			LastValue = NewValue
		end)
	end
end

VigilSpyHelper.Iteration.WatchTable = function(InstanceTable, Properties, Category)
	for _, Object in InstanceTable do
		VigilSpyHelper.Iteration.WatchInstanceProperties(Object, Properties, Category)
	end
end

--// main instance logger
task.spawn(function()
	local Scripts = {
		ServerScripts = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Script" }),
		LocalScripts = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "LocalScript" }),
		ModuleScripts = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ModuleScript" })
	}

	local UserInterfaces = {
		ScreenGui = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ScreenGui" }),
		SurfaceGui = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "SurfaceGui" }),
		BillBoardGui = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BillboardGui" }),
		AdGui = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "AdGui" }),
		Frame = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Frame" }),
		ScrollingFrame = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ScrollingFrame" }),
		TextLabel = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "TextLabel" }),
		TextButton = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "TextButton" }),
		TextBox = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "TextBox" }),
		ImageLabel = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ImageLabel" }),
		ImageButton = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ImageButton" }),
		VideoFrame = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "VideoFrame" }),
		ViewportFrame = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ViewportFrame" }),
		CanvasGroup = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "CanvasGroup" })
	}

	local RemoteObjects = {
		RemoteEvent = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "RemoteEvent" }),
		RemoteFunction = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "RemoteFunction" }),
		BindableEvent = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BindableEvent" }),
		BindableFunction = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BindableFunction" })
	}

	local FolderBasedObjects = {
		Folder = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Folder" }),
		Model = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Model" }),
		Configuration = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Configuration" }),
		SelectionBox = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "SelectionBox" }),
		SelectionSphere = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "SelectionSphere" })
	}

	local Values = {
		BinaryStringValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BinaryStringValue" }),
		BrickColorValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BrickColorValue" }),
		BoolValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "BoolValue" }),
		CFrameValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "CFrameValue" }),
		Color3Value = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Color3Value" }),
		DoubleConstrainedValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "DoubleConstrainedValue" }),
		IntConstrainedValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "IntConstrainedValue" }),
		IntValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "IntValue" }),
		NumberValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "NumberValue" }),
		ObjectValue = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "ObjectValue" }),
		Vector3Value = VigilSpyHelper.ObjectHelper.Filter({ ClassName = "Vector3Value" })
	}

	local Services = {
		AvatarEditorService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "AvatarEditorService" }),
		AdService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "AdService" }),
		AssetService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "AssetService" }),
		BadgeService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "BadgeService" }),
		BrowserService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "BrowserService" }),
		CaptureService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "CaptureService" }),
		Chat = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Chat" }),
		ClusterPacketCache = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ClusterPacketCache" }),
		CollectionService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "CollectionService" }),
		ContextActionService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ContextActionService" }),
		CookiesService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "CookiesService" }),
		CoreGui = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "CoreGui" }),
		DataStoreService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "DataStoreService" }),
		DraggerService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "DraggerService" }),
		FriendService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "FriendService" }),
		GamePassService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "GamePassService" }),
		GenerationService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "GenerationService" }),
		Geometry = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Geometry" }),
		GroupService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "GroupService" }),
		GuiService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "GuiService" }),
		HapticService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "HapticsService" }),
		HttpRbxApiService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "HttpRbxApiService" }),
		HttpService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "HttpService" }),
		InsertService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "InsertService" }),
		JointsService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "JointsService" }),
		KeyboardService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "KeyBoardService" }),
		Lighting = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Lighting" }),
		LocalizationService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "LocalizationService" }),
		LoginService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "LoginService" }),
		LogService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "LogService" }),
		LuaWebService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "LuaWebService" }),
		MarketplaceService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MarketplaceService" }),
		MatchmakingService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MatchmakingService" }),
		MaterialService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MaterialService" }),
		MemoryStoreService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MemoryStoreService" }),
		MessagingService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MessagingService" }),
		MicroProfilerService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MicroProfilerService" }),
		MLService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MLService" }),
		ModerationService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ModerationService" }),
		MouseService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "MouseService" }),
		NetworkClient = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "NetworkClient" }),
		NetworkServer = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "NetworkServer" }),
		NotificationService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "NotificationService" }),
		OpenCloudService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "OpenCloudService" }),
		PackageService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PackageService" }),
		PathfindingService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PathfindingService" }),
		PermissionsService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PermissionsService" }),
		PhysicsService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PhysicsService" }),
		PlayerEmulatorService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PlayerEmulatorService" }),
		Players = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Players" }),
		PolicyService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "PolicyService" }),
		ProximityPromptService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ProximityPromptService" }),
		ReplicatedFirst = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ReplicatedFirst" }),
		ReplicatedStorage = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ReplicatedStorage" }),
		RunService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "RunService" }),
		ScriptContext = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ScriptContext" }),
		Selection = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Selection" }),
		ServerScriptService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ServerScriptService" }),
		ServerStorage = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "ServerStorage" }),
		SocialService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "SocialService" }),
		SoundService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "SoundService" }),
		StarterGui = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "StarterGui" }),
		Stats = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Stats" }),
		TaskScheduler = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TaskScheduler" }),
		Teams = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Teams" }),
		TeleportService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TeleportService" }),
		TestService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TestService" }),
		TextChatService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TextChatService" }),
		TextService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TextService" }),
		TimerService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TimerService" }),
		TweenService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "TweenService" }),
		UGCValidationService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "UGCValidationService" }),
		UserInputService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "UserInputService" }),
		VRService = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "VRService" }),
		Workspace = VigilSpyHelper.ObjectHelper.FilterProxied({ ClassName = "Workspace" })
	}

	pcall(function()
		local Success = pcall(function() Instance.new("Script").RunContext = Enum.RunContext.Legacy end)
		if not Success then
			PrintConsole(2, "[ VigilSpy - Assistant ]: Failed to verify capabilities (Error code 0x8C)")
			return
		end

		local SupportSource = pcall(function() return Instance.new("LocalScript").Source end)
		if not SupportSource then
			PrintConsole(2, "[ VigilSpy - Assistant ]: Failed to verify capabilities (Error code 0x8C)")
			return
		end

		--// DO NOT MODIFY THIS
		VigilSpyHelper.Iteration.WatchTable(Scripts.ServerScripts, {"Name", "Parent", "Archivable", "RunContext"}, "Scripts")
		VigilSpyHelper.Iteration.WatchTable(Scripts.LocalScripts, {"Name", "Parent", "Archivable", "Source"}, "Scripts")
		VigilSpyHelper.Iteration.WatchTable(Scripts.ModuleScripts, {"Name", "Parent", "Archivable", "Source"}, "Scripts")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.ScreenGui, {"Name", "Parent", "Archivable", "DisplayOrder", "ClipToDeviceSafeArea", "IgnoreGuiInset", "SafeAreaCompatibility", "SafeInsets"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.AdGui, {"Name", "Parent", "Archivable", "AdShape", "EnableVideoAds", "FallbackImage", "Status"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.BillBoardGui, {"Name", "Parent", "Archivable", "Active", "Adornee", "AlwaysOnTop", "Brightness", "ClipsDescendants", "CurrentDistance", "DistanceStep", "ExtentsOffset", "ExtentsOffsetWorldSpace", "LightInfluence", "MaxDistance", "PlayerToHideFrom", "Size", "SizeOffset", "StudsOffset", "StudsOffsetWorldSpace"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.SurfaceGui, {"Name", "Parent", "Archivable", "AlwaysOnTop", "Brightness", "CanvasSize", "ClipsDescendants", "LightInfluence", "MaxDistance", "PixelsPerStud", "SizingMode", "ToolPunchThroughDistance", "ZOffset"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.Frame, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "Position", "Rotation", "Size", "SizeConstraint", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.ScrollingFrame, {"Name", "Parent", "Archivable", "AnchorPoint", "AutomaticCanvasSize", "BackgroundColor3", "BackgroundTransparency", "BottomImage", "CanvasPosition", "CanvasSize", "ClipsDescendants", "ElasticBehavior", "HorizontalScrollBarInset", "MidImage", "Position", "Rotation", "ScrollBarImageColor3", "ScrollBarImageTransparency", "ScrollBarThickness", "ScrollingDirection", "ScrollingEnabled", "Size", "TopImage", "VerticalScrollBarInset", "VerticalScrollBarPosition", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.TextLabel, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "ContentText", "Font", "FontFace", "LineHeight", "MaxVisibleGraphemes", "Position", "RichText", "Rotation", "Size", "SizeConstraint", "Text", "TextBounds", "TextColor3", "TextFits", "TextScaled", "TextSize", "TextStrokeColor3", "TextStrokeTransparency", "TextTransparency", "TextTruncate", "TextWrapped", "TextXAlignment", "TextYAlignment", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.TextButton, {"Name", "Parent", "Archivable", "AnchorPoint", "AutoButtonColor", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "ContentText", "Font", "FontFace", "LineHeight", "MaxVisibleGraphemes", "Modal", "Position", "RichText", "Rotation", "Selected", "Size", "SizeConstraint", "Style", "Text", "TextBounds", "TextColor3", "TextFits", "TextScaled", "TextSize", "TextStrokeColor3", "TextStrokeTransparency", "TextTransparency", "TextTruncate", "TextWrapped", "TextXAlignment", "TextYAlignment", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.TextBox, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClearTextOnFocus", "ClipsDescendants", "ContentText", "CursorPosition", "Font", "FontFace", "LineHeight", "MaxVisibleGraphemes", "MultiLine", "PlaceholderColor3", "PlaceholderText", "Position", "RichText", "Rotation", "SelectionStart", "ShowNativeInput", "Size", "SizeConstraint", "Text", "TextBounds", "TextColor3", "TextEditable", "TextFits", "TextScaled", "TextSize", "TextStrokeColor3", "TextStrokeTransparency", "TextTransparency", "TextTruncate", "TextWrapped", "TextXAlignment", "TextYAlignment", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.ImageLabel, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "Image", "ImageColor3", "ImageRectOffset", "ImageRectSize", "ImageTransparency", "IsLoaded", "Position", "ResampleMode", "Rotation", "ScaleType", "Size", "SizeConstraint", "SliceCenter", "SliceScale", "TileSize", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.ImageButton, {"Name", "Parent", "Archivable", "AnchorPoint", "AutoButtonColor", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "HoverImage", "Image", "ImageColor3", "ImageRectOffset", "ImageRectSize", "ImageTransparency", "IsLoaded", "Modal", "Position", "PressedImage", "ResampleMode", "Rotation", "ScaleType", "Selected", "Size", "SizeConstraint", "SliceCenter", "SliceScale", "TileSize", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.VideoFrame, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "IsLoaded", "Looped", "Playing", "Position", "Resolution", "Rotation", "Size", "SizeConstraint", "TimeLength", "TimePosition", "Video", "Visible", "Volume", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.ViewportFrame, {"Name", "Parent", "Archivable", "AnchorPoint", "Ambient", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "CurrentCamera", "ImageColor3", "ImageTransparency", "LightColor", "LightDirection", "Position", "Rotation", "Size", "SizeConstraint", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(UserInterfaces.CanvasGroup, {"Name", "Parent", "Archivable", "AnchorPoint", "BackgroundColor3", "BackgroundTransparency", "BorderColor3", "BorderMode", "BorderSizePixel", "ClipsDescendants", "GroupColor3", "GroupTransparency", "Position", "Rotation", "Size", "SizeConstraint", "Visible", "ZIndex"}, "Interfaces")
		VigilSpyHelper.Iteration.WatchTable(RemoteObjects.RemoteEvent, {"Name", "Parent", "Archivable"}, "Remotes")
		VigilSpyHelper.Iteration.WatchTable(RemoteObjects.RemoteFunction, {"Name", "Parent", "Archivable"}, "Remotes")
		VigilSpyHelper.Iteration.WatchTable(RemoteObjects.BindableEvent, {"Name", "Parent", "Archivable"}, "Remotes")
		VigilSpyHelper.Iteration.WatchTable(RemoteObjects.BindableFunction, {"Name", "Parent", "Archivable"}, "Remotes")
		VigilSpyHelper.Iteration.WatchTable(FolderBasedObjects.Folder, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(FolderBasedObjects.Model, {"Name", "Parent", "Archivable", "LevelOfDetail", "PrimaryPart", "Scale"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(FolderBasedObjects.Configuration, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(FolderBasedObjects.SelectionBox, {"Name", "Parent", "Archivable", "Adornee", "Color3", "LineThickness", "SurfaceColor3", "SurfaceTransparency", "Visible"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(FolderBasedObjects.SelectionSphere, {"Name", "Parent", "Archivable", "Adornee", "Color3", "SurfaceColor3", "SurfaceTransparency"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Values.BinaryStringValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.BrickColorValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.BoolValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.CFrameValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.Color3Value, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.DoubleConstrainedValue, {"Name", "Parent", "Archivable", "Value", "MaxValue", "MinValue"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.IntConstrainedValue, {"Name", "Parent", "Archivable", "Value", "MaxValue", "MinValue"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.IntValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.NumberValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.ObjectValue, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Values.Vector3Value, {"Name", "Parent", "Archivable", "Value"}, "Values")
		VigilSpyHelper.Iteration.WatchTable(Services.AvatarEditorService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.AdService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.AssetService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.BadgeService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.BrowserService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.CaptureService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Chat, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ClusterPacketCache, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.CollectionService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ContextActionService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.CookiesService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.CoreGui, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.DataStoreService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.DraggerService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.FriendService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.GamePassService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.GenerationService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Geometry, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.GroupService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.GuiService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.HapticService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.HttpRbxApiService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.HttpService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.InsertService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.JointsService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.KeyboardService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Lighting, {"Name", "Parent", "Archivable", "Ambient", "Brightness", "ClockTime", "ColorShift_Bottom", "ColorShift_Top", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ExposureCompensation", "FogColor", "FogEnd", "FogStart", "GeographicLatitude", "GlobalShadows", "OutdoorAmbient", "ShadowSoftness", "Technology", "TimeOfDay"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.LocalizationService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.LoginService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.LogService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.LuaWebService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MarketplaceService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MatchmakingService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MaterialService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MemoryStoreService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MessagingService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MicroProfilerService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MLService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ModerationService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.MouseService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.NetworkClient, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.NetworkServer, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.NotificationService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.OpenCloudService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PackageService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PathfindingService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PermissionsService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PhysicsService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PlayerEmulatorService, {"Name", "Parent", "Archivable", "CustomPoliciesEnabled", "EmulatedCountryCode", "EmulatedGameLocale", "PlayerEmulationEnabled", "StreamingEnabled"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Players, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.PolicyService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ProximityPromptService, {"Name", "Parent", "Archivable", "Enabled", "MaxPromptsVisible"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ReplicatedFirst, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ReplicatedStorage, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.RunService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ScriptContext, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Selection, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ServerScriptService, {"Name", "Parent", "Archivable", "LoadStringEnabled"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.ServerStorage, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.SocialService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.SoundService, {"Name", "Parent", "Archivable", "AmbientReverb", "DistanceFactor", "DopplerScale", "RespectFilteringEnabled", "RolloffScale", "VolumetricAudio"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.StarterGui, {"Name", "Parent", "Archivable", "ProcessUserInput", "ResetPlayerGuiOnSpawn", "ScreenOrientation", "ShowDevelopmentGui", "VirtualCursorMode"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Stats, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TaskScheduler, {"Name", "Parent", "Archivable", "SchedulerDutyCycle", "SchedulerRate"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Teams, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TeleportService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TestService, {"Name", "Parent", "Archivable", "Description", "ErrorCount", "ExecuteWithStudioRun", "Is30FpsThrottleEnabled", "IsPhysicsEnvironmentalThrottled", "IsSleepAllowed", "NumberOfPlayers", "SimulateSecondsLag", "TestCount", "Timeout", "WarnCount"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TextChatService, {"Name", "Parent", "Archivable", "ChatTranslationEnabled", "ChatVersion", "CreateDefaultCommands", "CreateDefaultTextChannels"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TextService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TimerService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.TweenService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.UGCValidationService, {"Name", "Parent", "Archivable"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.UserInputService, {"Name", "Parent", "Archivable", "GamepadEnabled", "KeyboardEnabled", "ModalEnabled", "MouseEnabled", "OnScreenKeyboardVisible", "TouchEnabled", "VREnabled"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.VRService, {"Name", "Parent", "Archivable", "AutomaticScaling", "FadeOutViewOnCollision", "GuiInputUserCFrame", "VRDeviceAvailable", "VREnabled"}, "Services")
		VigilSpyHelper.Iteration.WatchTable(Services.Workspace, {"Name", "Parent", "Archivable", "AirDensity", "AllowThirdPartySales", "CurrentCamera", "DistributedGameTime", "FallenPartsDestroyHeight", "GlobalWind", "Gravity", "PhysicsSimulationRate", "StreamingEnabled", "StreamingMinRadius", "StreamingTargetRadius", "TerrainWeldsFixed"}, "Services")
	end)
end)
