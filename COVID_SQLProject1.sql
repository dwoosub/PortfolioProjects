Select * 
From PortfolioProject..CovidDeaths
Where Continent is NOT NULL
order by 3,4

--Select * 
--From PortfolioProject..CovidVaccinations
--order by 3,4

-- Select Data that we are going to be using

Select Location, Date, total_cases, new_cases, total_deaths, population 
From PortfolioProject..CovidDeaths
Where Continent is NOT NULL
order by 1,2



--Looking at the Total Cases vs Total Deaths
-- Shows the likelihood of dying if you contract COVID in your country

Select Location, Date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProject..CovidDeaths
Where location like '%states%'
and Continent is NOT NULL
order by 1,2 



-- Looking at the total cases vs the population
-- Shows what percentage of population got COVID

Select Location, Date, population, total_cases, (total_cases/population)*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
Where Continent is NOT NULL
-- Where location like '%states%'
order by 1,2 



-- Looking at Countries with highest Infection Rate compared to Population

Select Location, population, MAX(total_cases) as HighestInfectionCount, MAX((total_cases/population))*100 as PercentPopulationInfected
From PortfolioProject..CovidDeaths
Where Continent is NOT NULL
-- Where location like '%states%'
GROUP by Location, Population
order by PercentPopulationInfected desc



-- Showing Countries with Highest Death Count per Population

Select Location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
-- Where location like '%states%'
Where Continent is NOT NULL
GROUP by Location 
order by TotalDeathCount desc


-- Showing continents with the highest death count per population 
-- You want Continent is NULL because the data has continents listed in the location column separately

Select location, MAX(cast(Total_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
-- Where location like '%states%'
Where Continent is NULL
GROUP by location
order by TotalDeathCount desc


-- Showing continents with the highest death count per population 
-- (Purpose for the drill down effect)

Select continent, MAX(cast(Total_deaths as int)) as TotalDeathCount
From PortfolioProject..CovidDeaths
-- Where location like '%states%'
Where Continent is NOT NULL
GROUP by continent
order by TotalDeathCount desc


-- GLOBAL NUMBERS. Death percentage per day

Select Date, sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths, sum(cast(new_deaths as int))/SUM(new_cases) *100  as DeathPercentage
From PortfolioProject..CovidDeaths
WHERE Continent is NOT NULL
GROUP BY date
order by 1,2 

-- Create View for GLOBAL NUMBERS 

Create View DeathPercentagebydate
as 
Select Date, sum(new_cases) as total_cases, sum(cast(new_deaths as int)) as total_deaths, sum(cast(new_deaths as int))/SUM(new_cases) *100  as DeathPercentage
From PortfolioProject..CovidDeaths
WHERE Continent is NOT NULL
GROUP BY date
--order by 1,2 

Select *
from DeathPercentagebydate


-- Looking at Total Population vs Vaccinations

Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100 does not work cuz alias made in select can't be used as a column in the select
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is NOT NULL
Order By 2,3


-- USE CTE for Total Population vs Vaccinations (rolling count)
-- Note that the # of columns in CTE must match the  # of columns in the Select statement

WITH PopvsVac (Continent, Location, Date, Population, new_vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100 does not work cuz alias made in select can't be used as a column in the select
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
Where dea.continent is NOT NULL
--Order By 2,3
)
Select *, (RollingPeopleVaccinated/Population)*100
From PopvsVac



-- Temp Table vs using CTE method for Total Population vs Vaccinations (rolling count)
-- Used DROP Table if in case you wanted to change some lines in the Table. Easier to maintain

DROP Table if exists #PercentPopulationVaccinated 
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100 does not work cuz alias made in select can't be used as a column in the select
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
--where dea.continent is NOT NULL
--Order By 2,3

Select *, (RollingPeopleVaccinated/Population)*100
From #PercentPopulationVaccinated


-- Creating View to store data for later visualizations 
-- Used Total Population vs Vaccinations (rolling count) code

Create View PercentPopulationVaccinated as 
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(bigint,vac.new_vaccinations)) OVER (Partition by dea.location order by dea.location, dea.date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100 does not work cuz alias made in select can't be used as a column in the select
From PortfolioProject..CovidDeaths dea
Join PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location
	and dea.date = vac.date
where dea.continent is NOT NULL
--Order By 2,3


Select * 
From PercentPopulationVaccinated

