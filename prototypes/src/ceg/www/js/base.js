dojo.provide("humanapi.ceg");

dojo.require("dojo.date.locale");

humanapi.ceg = function(){
	// summary:
	//		An application to display ECG information

	// decription:
	//		HumanAPI ECG is a project which lets you display
	//		ECG data on a mobile application
	//		To get it running you need to be able to access the
	//		bluetooth layer on your device

	// Mixin defaults
	dojo.mixin(this, {
		ecgData: [],

		// Buttons
		nlButtonStart: dojo.query(".button.start"),
		nlButtonAdv: dojo.query(".button.adv"),
		nlButtonOverview: dojo.query(".button.overview"),
		nlButtonHome: dojo.query(".button.home"),
		nlButtonEdit: dojo.query(".button.edit"),

		// Application views
		nlViewDefault: dojo.query(".view.default"),
		nlViewOverview: dojo.query(".view.overview"),
		nlViewDetails: dojo.query(".view.details"),

		// Common
		nlHeartRate: dojo.query(".heartRate"),
		nlDeviceInfo: dojo.query("img.connectionInfo"),
		nlSessionTime: dojo.query("span.time"),

		// Log
		nlLogBody: dojo.query(".body.list"),

		// Details
		nlContainerMap: dojo.query(".container.map"),
		nlTrainingDate: dojo.query(".trainingDate"),
		nlTrainingLength: dojo.query(".trainingLength"),
		nlTrainingMin: dojo.query(".trainingMin"),
		nlTrainingMax: dojo.query(".trainingMax"),
		nlTrainingAvg: dojo.query(".trainingAvg"),

		map: dojo.byId("map"),

		currentView: dojo.query(".view.default"),
		previousView: null,

		// Set this and implement a warning algorithm,
		// this.alarm() will get called
		threshold: 120,
		status: 0, // Connection status
		session: null, // Object to store training data

		// Need this for drawing purposes
		ecgPosition: dojo.position(dojo.byId("ecg")),

		currentHeartRate: null, // Current heartrate
		avgCnt: 0,
		avgTotal: 0,

		min: null,
		max: null,

		connected: false,

		evt: [], // Array to store event connections

		// Templates
		overviewRow: '<a href="#" id="{{ id }}" class="listItem"><div class="displayNone floatLeft"><span class="button bad mini" id="del_{{ id }}">Delete</span></div>{{ start }}<br /><span class="info">Duration: {{ stop }}</span></a>'
	});

	var _t = this;

	this.init = function(){
		// summary:
		//		ECG initialization

		this.c = document.getElementById("ecg");
		this.ctx = _t.c.getContext("2d");

		// Starts the training program
		this.nlButtonStart.onclick(_t, "trainingTrigger");

		// Activates advanced logging of geolocation and heart rate
		this.nlButtonAdv.onclick(_t, "activateAdv");

		// We don't have any intelligent page/view handling yet and
		// just display the page we want to show after the current
		// page gets hidden. This could be solved more elegantly.
		this.initButtons();

		this.openDb();
	};

	// Bluetooth data receival
	dojo.subscribe("packet/new", function(msg){
		msg = msg.replace(/\s+$/,""); // Right trim whitespace
		var data = msg.split(" ");

		// Set connection status
		_t.connected = true;

		if (data.length == 5 && data[4].length == 0){ // First four items are info
			return;
		}

		_t.status = data.shift();

		var cnt = data.shift(), // current iteration
			dataStatus = data.shift(), // if different than 1 no valid data
			totalCnt = data.shift(); // total count of ecg iterations

		// First display the current heart rate
		if (_t.status < 1){
			_t.nlDeviceInfo.addClass("disabled");
		}else{
			_t.nlDeviceInfo.removeClass("disabled");
		}

		_t.ecgData = [data[0]].concat(_t.ecgData); // only add latest value

		// Clean up the data array
		while (_t.ecgData.length > _t.ecgPosition.w){
			_t.ecgData.pop();
		}

		_t.paintEcg();
	});

	this.initButtons = function(){
		this.nlButtonOverview.onclick(function(e){
			_t.previousView = _t.currentView;
			_t.currentView = _t.nlViewOverview;

			_t.previousView.toggleClass("displayNone");
			_t.currentView.toggleClass("displayNone");

			_t.onViewShow("overview");
		});

		this.nlButtonHome.onclick(function(e){
			_t.previousView = _t.currentView;
			_t.currentView = _t.nlViewDefault;

			_t.previousView.toggleClass("displayNone");
			_t.currentView.toggleClass("displayNone");

			_t.onViewShow("home");
		});

		var editState = "edit",
			handles,
			editButton,
			editFunc = function(evt){
				editButton = evt.target;

				var items = dojo.query(".listItem .floatLeft");

				if (editState == "edit"){
					dojo.attr(evt.target, "innerHTML", "Done");
					editState = "done";
					items.removeClass("displayNone");
					handles = dojo.query(".listItem .floatLeft .button").map(function(x) {
						return dojo.connect(x, "onclick", function(e) {
							dojo.stopEvent(e);

							var id = dojo.attr(e.target, "id"),
								idSplit = id.split("_");

							if (idSplit[0] == "del"){
								// Uncomment if you want to stop editing
								// after deleting one item
								//editFunc(evt);
								_t.deleteEntry(idSplit[1]);
							}
						});
					});
				}else{
					dojo.attr(evt.target, "innerHTML", "Edit");
					editState = "edit";
					items.addClass("displayNone");
					dojo.forEach(handles, function(x) {
						dojo.disconnect(x);
					});
				}
			}
		;

		dojo.connect(this, "onViewShow", this, function(view){
			if ((view == "home" || view == "details") && editState == "done"){
				editFunc({target: editButton});
			}
		});

		this.nlButtonEdit.onclick(editFunc);
	};

	this.onViewShow = function(view){
		// summary:
		//		Gets called when a view gets shown
	};

	this.trainingTrigger = function(e){
		if (!this.connected){
			alert("You seem not to be connected, recording anyways.");
		}

		this.nlButtonStart.toggleClass("bad")
			.toggleClass("good")
			.attr("innerHTML", dojo.hasClass(e.target, "bad") ? "Stop" : "Start");

		if (!this.session){
			this.nlSessionTimer = new Date();

			// reset
			this.nlSessionTimer.setHours(0);
			this.nlSessionTimer.setMinutes(0);
			this.nlSessionTimer.setSeconds(0);

			this.nlSessionTime.attr("innerHTML", dojo.date.locale.format(_t.nlSessionTimer, {timePattern:'HH:mm:ss',selector:'time'}));
			this.session = {
				start: (new Date()).getTime()
			}
			this.intv = setInterval(function(){
				_t.nlSessionTimer = dojo.date.add(_t.nlSessionTimer, "second", 1);
				_t.nlSessionTime.attr("innerHTML", dojo.date.locale.format(_t.nlSessionTimer, {timePattern:'HH:mm:ss',selector:'time'}));
			}, 1000);
		}else{ // Save data
			this.nlSessionTime.attr("innerHTML", "00:00");
			clearInterval(this.intv);

			dojo.mixin(this.session, {
				stop: this.nlSessionTimer,
				minRate: this.min,
				maxRate: this.max,
				avgRate: Math.round((this.avgTotal / this.avgCnt)*Math.pow(10,2))/Math.pow(10,2) // Round
			});

			this.saveEntry(this.session);

			delete this.session;

			this.avg = 0;
			this.avgTotal = 0;
			this.avgCnt = 0;
			this.min = null;
			this.max = null;
		}
	};

	this.activateAdv = function(e){
		this.nlButtonAdv.toggleClass("bad")
			.toggleClass("good")
			.attr("innerHTML", dojo.hasClass(e.target, "bad") ? "Off" : "On");

		if (dojo.hasClass(e.target, "good")){
			this.trackDetailed = true;
			this.geoWatch = navigator.geolocation.watchPosition(function(pos){
				if (_t.session && _t.nlSessionTimer){
					if (!_t.session.adv){
						_t.session.adv = [];
					}

					_t.session.adv.push({
						time: dojo.date.locale.format(_t.nlSessionTimer, {timePattern:'mm:ss',selector:'time'}),
						lat: pos.coords.latitude,
						lng: pos.coords.longitude,
						rate: _t.currentHeartRate
					});
				}
			});
		}else{
			this.trackDetailed = false;
			if (this.geoWatch){
				navigator.geolocation.clearWatch(this.geoWatch);
			}
		}
	};

	this.evt.listHandles = [];
	this.renderLog = function(data){
		dojo.forEach(this.evt.listHandles, function(x) {
			dojo.disconnect(x);
		});

		var container = this.nlLogBody[0];
		while (container.firstChild){
			container.removeChild(container.firstChild);
		}

		var str = this.overviewRow,
			val;
		for (var i = 0; i < data.length; ++i) {
			var row = data.item(i),
				str = this.overviewRow;
			for (var key in row){
				if (key == "start"){
					val = dojo.date.locale.format(new Date(row[key]), {formatLength:'short'});
				}else if (key == "stop"){
					val = dojo.date.locale.format(new Date(row[key]), {timePattern:'HH:mm:ss', selector:'time'});
				}else{
					val = row[key];
				}
				str = str.replace(new RegExp("{{ "+key+" }}", "g"), val);
			}
			container.appendChild(dojo._toDom(str));
		}

		this.evt.listHandles = dojo.query(".overview .listItem").map(function(x) {
			return dojo.connect(x, "onclick", function(e) {
				var id = dojo.attr(e.target, "id");

				// Show details page if available
				_t.previousView = _t.currentView;
				_t.currentView = _t.nlViewDetails;

				_t.renderDetails(id);

				_t.previousView.toggleClass("displayNone");
				_t.currentView.toggleClass("displayNone");

				_t.onViewShow("details");
			});
		});
	};

	this.renderDetails = function(id){
		// reset
		this.nlContainerMap.addClass("displayNone");

		// draw route
		var callb = function(data){
			this.nlTrainingDate.attr("innerHTML", dojo.date.locale.format(new Date(data.start), {formatLength:'short'}));
			this.nlTrainingLength.attr("innerHTML", dojo.date.locale.format(new Date(data.stop), {timePattern:'HH:mm:ss', selector:'time'}));
			this.nlTrainingMin.attr("innerHTML", data.minRate ? data.minRate : "Not available");
			this.nlTrainingMax.attr("innerHTML", data.maxRate ? data.maxRate : "Not available");
			this.nlTrainingAvg.attr("innerHTML", data.avgRate ? data.avgRate : "Not available");

			// Handle map if data are available
			var advData = data.adv ? dojo.fromJson(data.adv) : [];
			if (advData.length){
				this.nlContainerMap.removeClass("displayNone");

				var avgLat = 0,
					avgLng = 0,
					trackCoords = [];
				dojo.forEach(advData, function(item){
					avgLat += parseFloat(item.lat);
					avgLng += parseFloat(item.lng);
					trackCoords.push(new google.maps.LatLng(item.lat, item.lng));
				});
				avgLat /= advData.length;
				avgLng /= advData.length;

				if (this.mapInstance){
					dojo.destroy(this.mapInstance);
				}

				var myOptions = {
					zoom: 16,
					mapTypeId: google.maps.MapTypeId.ROADMAP,
					scaleControl: true
				};
				dojo.destroy(this.map.firstChild);
				this.mapInstance = new google.maps.Map(dojo.create("div", {style:{ width: "100%", height: "100%"}}, this.map, "first"), myOptions);

				var latlng = new google.maps.LatLng(avgLat, avgLng);
				this.mapInstance.setCenter(latlng);

				this.trackPath = new google.maps.Polyline({
					path: trackCoords,
					strokeColor: "#FF0000",
					strokeOpacity: 1.0,
					strokeWeight: 4
				});

				this.trackPath.setMap(this.mapInstance);
			}else{
				this.nlContainerMap.addClass("displayNone");
			}
		};

		this.getEntry(id, callb);
	};

	this.paintEcg = function(){
		// summary:
		//		Draws the ECG to the canvas
		// Current heart rate
		this.ecgData[0] = parseInt(this.ecgData[0]);

		if (isNaN(this.ecgData[0])){
			return;
		}

		this.nlHeartRate.attr("innerHTML", this.ecgData[0]);
		this.currentHeartRate = this.ecgData[0];

		if (!this.max || this.currentHeartRate > this.max){
			this.max = this.currentHeartRate;
		}

		if (!this.min || this.currentHeartRate < this.min){
			this.min = this.currentHeartRate;
		}

		// calculate avg
		this.avgTotal += parseInt(this.ecgData[0]);
		this.avgCnt++;

		// clear canvas
		this.ctx.clearRect(0,0,this.c.width,this.c.height); // clear canvas
		this.ctx.fillStyle = "rgb(207,233,201)";
		this.ctx.fillRect(0,0,this.c.width,this.c.height);

		this.ctx.beginPath();
		this.ctx.strokeStyle = "rgb(25,66,16)";

		var px = 0, py = 0, x=0, item;
		this.ctx.moveTo(this.ecgData[0], 0);
		for (var i=0; i<this.ecgData.length; i++){
			if (i<=this.ecgPosition.w){ // displayable width
				// A very simple alarm system :)
				if (this.ecgData[i] > this.threshold){
					this.alarm();
				}

				x=i*this.ecgPosition.w/20;
				y = this.ecgPosition.h-this.ecgData[i];

				this.ctx.moveTo(px, py);
				this.ctx.lineTo(x, y);

				py = y;
				px = x;
			}
		}

		this.ctx.stroke();
		this.ctx.closePath();
	};

	this.alarm = function(){
		// Do something based on bad heart rates
	};

	this.openDb = function(){
		// summary:
		//		Opens the loal database to store readings

		try {
			if (window.openDatabase) {
				this.db = openDatabase(
					"HumanApiSports",
					"1.0",
					"Sports data", 200000
				);

				if (!this.db){
					alert("Failed to open the database on disk. This is probably because the version was bad or there is not enough space left in this domain's quota");
				}
			}else{
				alert("Couldn't open the database. This feature might not be supported on your browser");
			}
		} catch(err) { }

		this.loadDb();
	};


	this.loadDb = function(){
		// summary:
		//		Checks whether the database has the required
		//		tables - if not, creates them

		this.db.transaction(function(tx) {
			tx.executeSql("SELECT COUNT(*) FROM CegData",
				[],
				function(result) {
					_t.getEntries(_t.renderLog);
				}, function(tx, error) {
					tx.executeSql("CREATE TABLE CegData (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, start REAL, stop REAL, minRate REAL, maxRate REAL, avgRate REAL, adv TEXT)", [], function(result) {
						_t.getEntries(_t.renderLog);
					});
				}
			);
		});
	};

	this.evt.listHandles = [];
	this.getEntries = function(callb){
		// summary:
		//		Loads available temperature readings

		this.db.transaction(function(tx) {
			tx.executeSql("SELECT id, start, stop, minRate, maxRate, avgRate, adv FROM CegData ORDER BY id DESC", [], function(tx, result) {
				callb.call(_t, result.rows);
			}, function(tx, error) {
			    alert('Failed to retrieve saved sports data readings from database - ' + error.message);
			    return;
			});
		});
	};

	this.getEntry = function(id, callb){
		this.db.transaction(function(tx) {
			tx.executeSql("SELECT id, start, stop, minRate, maxRate, avgRate, adv FROM CegData WHERE id = ?", [id], function(tx, result) {
				callb.call(_t, result.rows.item(0));
			}, function(tx, error) {
			    alert('Failed to retrieve saved sports data readings from database - ' + error.message);
			    return;
			});
		});
	};

	this.saveEntry = function(entry){
		// summary:
		//		Saves temperature reading to local database

		if (!entry){
			alert("No sports data readings available");
			return;
		}

		var timestamp = new Date().getTime();

		this.db.transaction(function (tx){
			tx.executeSql("INSERT INTO CegData (start, stop, minRate, maxRate, avgRate, adv) VALUES (?, ?, ?, ?, ?, ?)", [entry.start, entry.stop, entry.minRate, entry.maxRate, entry.avgRate, entry.adv ? dojo.toJson(entry.adv) : ""], function(){
				alert("Reading saved!");
				_t.getEntries(_t.renderLog);
			});
		});
	};

	this.deleteEntry = function(id){
		this.db.transaction(function (tx){
			tx.executeSql("DELETE FROM CegData WHERE id = ?", [id], function(){
				// Remove entry
				dojo.query("#"+id).orphan();
			});
		});
	};
};

// Application setup
dojo.ready(function(){
	var instance = new humanapi.ceg();
	instance.init();
});