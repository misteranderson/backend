CREATE TABLE stage.status_rider
( 
  "RiderID" integer NOT NULL DEFAULT nextval('nov2016."RIDER_RiderID_seq"'::regclass),
  "status" integer NOT NULL DEFAULT 1,
  "CreatedTimeStamp" timestamp without time zone NOT NULL
)
WITH (
  OIDS=FALSE
);
ALTER TABLE stage.status_rider
  OWNER TO carpool_admins;
GRANT ALL ON TABLE stage.status_rider TO carpool_admins;
GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE stage.status_rider TO carpool_role;

CREATE TABLE stage.status_driver
( 
  "DriverID" integer NOT NULL DEFAULT nextval('nov2016."DRIVER_DriverID_seq"'::regclass),
  "status" integer NOT NULL DEFAULT 1,
  "TimeStamp" timestamp without time zone NOT NULL
)
WITH (
  OIDS=FALSE
);
ALTER TABLE stage.status_driver
  OWNER TO carpool_admins;
GRANT ALL ON TABLE stage.status_driver TO carpool_admins;
GRANT SELECT, UPDATE, INSERT, DELETE ON TABLE stage.status_driver TO carpool_role;

-- NOTE: All code in a function exists in a transaction.
--       Either it all succeeds or it is all rolled back
CREATE FUNCTION stage.create_riders() RETURNS timestamp AS $$
DECLARE
    tstamp timestamp := '2000-01-01';
BEGIN
    RAISE NOTICE 'tstamp here is %', tstamp; 

    -- get timestamp of unprocessed riders 
    IF EXISTS (select 1 from stage.status_rider) THEN
      select MAX("CreatedTimeStamp") into tstamp from stage.status_rider;
    ELSE 
      tstamp := '2010-01-01';
    END IF;

    -- create intermediate table of timestamps, processed flag and riderId
    INSERT INTO 
      stage.status_rider ("CreatedTimeStamp")     
    SELECT 
      "CreatedTimeStamp" FROM stage.websubmission_rider 
    WHERE 
      "CreatedTimeStamp" > tstamp;

    -- create riders in nov2016 db
    -- only insert riders in intermediate tables, and with status == 1
    -- ?? timestamp to be creation of nov2016 row, or original submission ??
    INSERT INTO 
      nov2016.rider 
        (
        "RiderID", "Name", "Phone", "Email", "EmailValidated",
        "State", "City", "Notes", "DataEntryPoint", "VulnerablePopulation",
        "NeedsWheelChair", "Active"
        )     
    SELECT
      stage.status_rider."RiderID",
      concat_ws(' ', 
                stage.websubmission_rider."RiderFirstName"::text, 
                stage.websubmission_rider."RiderLastName"::text) 
      ,
      stage.websubmission_rider."RiderPhone",
      stage.websubmission_rider."RiderEmail",
      stage.websubmission_rider."RiderEmailValidated"::int::bit,

      stage.websubmission_rider."RiderVotingState",
      'city?',
      'notes?',
      'entry?',
      stage.websubmission_rider."RiderIsVulnerable"::int::bit,

      stage.websubmission_rider."NeedWheelchair"::int::bit,
      true::int::bit
    FROM 
      stage.websubmission_rider
    INNER JOIN 
      stage.status_rider 
    ON 
      (stage.websubmission_rider."CreatedTimeStamp" = stage.status_rider."CreatedTimeStamp") 
    WHERE 
          stage.websubmission_rider."CreatedTimeStamp" > tstamp 
      AND stage.status_rider.status = 1;
    
    UPDATE 
      stage.status_rider
    SET
      status = 100
    WHERE
          stage.status_rider."CreatedTimeStamp" > tstamp 
      AND stage.status_rider.status = 1;

    -- RAISE EXCEPTION 'Nonexistent ID --> %', user_id
    --   USING HINT = 'Please check your user ID';

    RETURN tstamp;
END;
$$ LANGUAGE plpgsql;

GRANT ALL ON FUNCTION stage.create_riders() TO carpool_admins;
GRANT EXECUTE ON FUNCTION stage.create_riders() TO carpool_role;

-- NOTE: All code in a function exists in a transaction.
--       Either it all succeeds or it is all rolled back
CREATE FUNCTION stage.create_drivers() RETURNS timestamp AS $$
DECLARE
    tstamp timestamp := '2000-01-01';
BEGIN
    RAISE NOTICE 'tstamp here is %', tstamp; 

    -- get timestamp of unprocessed drivers 
    IF EXISTS (select 1 from stage.status_driver) THEN
      select MAX("TimeStamp") into tstamp from stage.status_driver;
    ELSE 
      tstamp := '2010-01-01';
    END IF;

    -- create intermediate table of timestamps, processed flag and driverId
    INSERT INTO 
      stage.status_driver ("TimeStamp")     
    SELECT 
      "TimeStamp" FROM stage.websubmission_driver 
    WHERE 
      "TimeStamp" > tstamp;

    -- create drivers in nov2016 db
    -- only insert drivers in intermediate tables, and with status == 1
    -- ?? timestamp to be creation of nov2016 row, or original submission ??
    INSERT INTO 
      nov2016.driver 
        (
        "DriverID", "Name", "Phone", "Email", "State", "City", "Origin",
        "Seats", "CreatedBy", 
        "EmailValidated", "DriverHasInsurance", "DriverWheelchair"
        )     
    SELECT
      stage.status_driver."DriverID",
      concat_ws(' ', 
                stage.websubmission_driver."DriverFirstName"::text, 
                stage.websubmission_driver."DriverLastName"::text),
      stage.websubmission_driver."DriverPhone",
      stage.websubmission_driver."DriverEmail",
      'State?', 'City?', 'Origin?',

      stage.websubmission_driver."SeatCount",
      'sweeper',
      stage.websubmission_driver."DriverEmailValidated",
      stage.websubmission_driver."DriverHasInsurance",
      stage.websubmission_driver."DriverCanLoadRiderWithWheelchair"
    FROM 
      stage.websubmission_driver
    INNER JOIN 
      stage.status_driver 
    ON 
      (stage.websubmission_driver."TimeStamp" = stage.status_driver."TimeStamp") 
    WHERE 
          stage.websubmission_driver."TimeStamp" > tstamp 
      AND stage.status_driver.status = 1;
    
    UPDATE 
      stage.status_driver
    SET
      status = 100
    WHERE
          stage.status_driver."TimeStamp" > tstamp 
      AND stage.status_driver.status = 1;

    RETURN tstamp;
END;
$$ LANGUAGE plpgsql;

GRANT ALL ON FUNCTION stage.create_drivers() TO carpool_admins;
GRANT EXECUTE ON FUNCTION stage.create_drivers() TO carpool_role;

CREATE TABLE nov2016.driver_available_times
(
  "DriverID" integer NOT NULL DEFAULT nextval('nov2016."DRIVER_DriverID_seq"'::regclass),
  "RideDate" date,
  "RideTimeStart" time with time zone,
  "RideTimeEnd" time with time zone,
  CONSTRAINT driver_available_times_driver_DriverID_fkey FOREIGN KEY ("DriverID")
      REFERENCES nov2016.driver ("DriverID") MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE NO ACTION
)
WITH (
  OIDS=FALSE
);
ALTER TABLE nov2016.driver_available_times
  OWNER TO carpool_admins;
GRANT ALL ON TABLE nov2016.driver_available_times TO carpool_admins;
GRANT ALL ON TABLE nov2016.driver_available_times TO carpool_role;
