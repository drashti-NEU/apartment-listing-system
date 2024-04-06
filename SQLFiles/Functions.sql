USE ApartmentListingSystem;
GO

-- GetListerPropertyStats returns a table with various statistics related to the properties listed by a specific lister. 
-- It calculates the total number of properties listed, the count of active and inactive properties, the count of rental and sale properties, 
-- as well as statistics such as maximum and minimum bedrooms, bathrooms, and area sizes.
CREATE FUNCTION GetListerPropertyStats (@ListerID INTEGER)
RETURNS TABLE
AS
RETURN (
    SELECT
        @ListerID AS ListerID,
        COUNT(*) AS TotalPropertiesListed,
        SUM(CASE WHEN l.Listing_Status = 'Active' THEN 1 ELSE 0 END) AS ActiveProperties,
        SUM(CASE WHEN l.Listing_Status = 'Inactive' THEN 1 ELSE 0 END) AS InactiveProperties,
        SUM(CASE WHEN l.Listing_Type = 'R' THEN 1 ELSE 0 END) AS RentalProperties,
        SUM(CASE WHEN l.Listing_Type = 'S' THEN 1 ELSE 0 END) AS SaleProperties,
        MAX(pd.Bedroom) AS MaxBedrooms,
        MIN(pd.Bedroom) AS MinBedrooms,
        MAX(pd.Bathroom) AS MaxBathrooms,
        MIN(pd.Bathroom) AS MinBathrooms,
        AVG(pd.Area_Size) AS AvgAreaSize,
        MAX(pd.Area_Size) AS MaxAreaSize,
        MIN(pd.Area_Size) AS MinAreaSize
    FROM Property p
    JOIN Property_Detail pd ON p.Property_ID = pd.Property_ID
    JOIN Listing l ON p.Property_ID = l.Property_ID
    WHERE p.Lister_ID = @ListerID
);

SELECT * from GetListerPropertyStats(6);

-- GetFullNameOfUser retrieves the full name of the user associated with the provided user ID by concatenating the 
-- First_Name and Last_Name columns from the [User] table
CREATE OR ALTER FUNCTION GetFullNameOfUser(@UserID INTEGER)
RETURNS VARCHAR(50)
AS 
BEGIN 
    DECLARE @FullName VARCHAR(100);

    SELECT @FullName = CONCAT(First_Name, ' ', Last_Name)
    FROM [User]
    WHERE User_ID = @UserID;

    RETURN @FullName;
END;

SELECT *, dbo.GetFullNameOfUser(User_ID) AS Full_Name FROM [User];


-- GetTopRatedListers retrieves the top N listers based on their average rating and the number of active properties they have listed.
-- It orders the results by average rating and total active properties in descending order and returns the top N listers.
CREATE OR ALTER FUNCTION GetTopRatedListers(@N INT)
RETURNS TABLE
AS
RETURN (
    SELECT TOP (@N) 
        L.Lister_ID,
        dbo.GetFullNameOfUser(U.User_ID) AS Full_Name,
        AVG(R.Rating) AS Average_Rating,
        COUNT(DISTINCT P.Property_ID) AS Total_Active_Properties
    FROM Lister L
    INNER JOIN [User] U ON L.Lister_ID = U.User_ID
    INNER JOIN Review R ON L.Lister_ID = R.Lister_ID
    INNER JOIN Property P ON L.Lister_ID = P.Lister_ID
    INNER JOIN Listing LI ON P.Property_ID = LI.Property_ID
    WHERE LI.Listing_Status = 'Active'
    GROUP BY L.Lister_ID, U.User_ID
    ORDER BY Average_Rating DESC, Total_Active_Properties DESC
);

SELECT * FROM dbo.GetTopRatedListers(12);


-- UDF that calculates the total cost of renting a property for a given duration, taking into account the monthly rent, move-in cost, and security deposit.
--This UDF will take three parameters: Rent_ID (identifying the rental), DurationInMonths (the duration of the rental), and MoveInDate (the date when the rental begins).
CREATE OR ALTER FUNCTION CalculateTotalRentCost (
    @RentID INTEGER,
    @DurationInMonths INTEGER,
    @MoveInDate DATETIME
)
RETURNS DECIMAL(10, 2)
AS
BEGIN
    DECLARE @TotalCost DECIMAL(10, 2);
    SELECT @TotalCost =
        (RT.Monthly_Rent * @DurationInMonths) +
        R.Move_In_Cost +
        R.Security_Deposit
    FROM Rent_Transaction RT
	join Rent R on RT.Rent_ID = R.Rent_ID
    WHERE RT.Rent_ID = @RentID
    AND RT.Transaction_Date = (
        SELECT MAX(Transaction_Date)
        FROM Rent_Transaction
        WHERE Rent_ID = @RentID
        AND Transaction_Date <= @MoveInDate
    );
    RETURN @TotalCost;
END;

DECLARE @RentID INTEGER = 1; -- Provide the Rent ID
DECLARE @DurationInMonths INTEGER = 6; -- Duration in months
DECLARE @MoveInDate DATETIME = '2024-04-01'; -- Move in date
 
SELECT dbo.CalculateTotalRentCost(@RentID, @DurationInMonths, @MoveInDate) AS TotalCost;


-- UDF Computed Column functions

--Computed Column for Lister Activity Status
--UDF to determine the activity status of a Lister based on their number of active properties:
-- Created a UDF to determine Lister activity status
CREATE OR ALTER FUNCTION DetermineListerActivityStatus
(
    @ListerID INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @ActivityStatus NVARCHAR(50);

    SELECT @ActivityStatus = 
        CASE 
            WHEN Active_Properties > 0 THEN 'Active'
            ELSE 'Inactive'
        END
    FROM Lister
    WHERE Lister_ID = @ListerID;

    RETURN @ActivityStatus;
END;
GO

-- Add a computed column to the Lister table for Activity_Status
ALTER TABLE Lister
ADD Activity_Status AS dbo.DetermineListerActivityStatus(Lister_ID);
GO

