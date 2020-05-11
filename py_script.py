from sklearn.impute import SimpleImputer
import pandas as pd
import requests
import numpy as np
import json

token="gumYTVBRNjvqvibHdDoWcxRLceFIrCae"
start_year = 2012
end_year = 2017
fip_code = nc_counties[36]
url = f"https://www.ncdc.noaa.gov/cdo-web/api/v2/data?datasetid=GSOY&locationid=FIPS:{fip_code}&datatype=AWND&limit=1000&startdate={start_year}-01-01&enddate={end_year}-12-31"
weather_response = requests.get(url,headers={'token':token})

d = json.loads(weather_response.text)
data = {
    "FIPS":[],
    "year":[],
    'datatype': [],
    'station': [],
    'value': []
       }
for i in d['results']:
    data["FIPS"].append(fip_code)
    data['year'].append(i['date'].split("-")[0])
    data['datatype'].append(i['datatype'])
    data['station'].append(i['station'])
    data['value'].append(i['value'])
    
group_by = pd.DataFrame(data).groupby(["FIPS","datatype","year"], as_index=False).mean()
df = pd.DataFrame(group_by)
not_avail = []
try:
    new_df = df.loc[df["year"].isin(["2017","2012"]) & df["datatype"].isin(["PRCP","TAVG","TMAX","TMIN","HTDD", "CLDD"])]
    if new_df.empty:
        new_df = df.loc[df["year"].isin(["2016","2013"]) & df["datatype"].isin(["PRCP","TAVG","TMAX","TMIN","HTDD", "CLDD"])]
    df = pd.pivot_table(new_df, index=['FIPS','year'], columns='datatype', values='value',aggfunc=np.mean)
    df = df.rename_axis(None, axis=1).reset_index()
except:
    not_avail.append(fip_code)
    
county_df = pd.read_csv("USCounties.csv")
nc_county_df = county_df.loc[county_df['STATE_NAME'] == "North Carolina"].reset_index(drop=True)
nc_fips = list(nc_county_df.FIPS.unique())

def get_fip_data(fip_code):
    start_year = 2012
    end_year = 2017
    token="gumYTVBRNjvqvibHdDoWcxRLceFIrCae"
    url = f"https://www.ncdc.noaa.gov/cdo-web/api/v2/data?datasetid=GSOY&locationid=FIPS:{fip_code}&datatype=AWND&limit=1000&startdate={start_year}-01-01&enddate={end_year}-12-31"
    weather_response = requests.get(url,headers={'token':token})
    d = json.loads(weather_response.text)
    
    data = {
        "FIPS":[],
        "year":[],
        'datatype': [],
        'station': [],
        'value': []
           }
    
    for i in d['results']:
        data["FIPS"].append(fip_code)
        data['year'].append(i['date'].split("-")[0])
        data['datatype'].append(i['datatype'])
        data['station'].append(i['station'])
        data['value'].append(i['value'])
    
    group_by = pd.DataFrame(data).groupby(["FIPS","datatype","year"], as_index=False).mean()
    df = pd.DataFrame(group_by)
    new_df = df.loc[df["year"].isin(["2017","2012"]) & df["datatype"].isin(["PRCP","TAVG","TMAX","TMIN","HTDD", "CLDD"])]
    df = pd.pivot_table(new_df, index=['FIPS','year'], columns='datatype', values='value',aggfunc=np.mean)
    df = df.rename_axis(None, axis=1).reset_index()
    return df

def get_complete_data():
    list_fips = []
    not_avail = []
    
    i = 0
    while i < len(nc_counties):
        try:
            list_fips.append(get_fip_data(nc_counties[i]))
        except:
            not_avail.append(nc_counties[i])
        i += 1
    
    result = pd.concat(list_fips).reset_index(drop=True)
    list_2012 = list(result.loc[result["year"] == "2012"]['FIPS'].unique())
    year_2017 = result.loc[result["year"] == "2017"].reset_index(drop=True)
    year_2017.loc[year_2017["FIPS"].isin(list_2012)]

    result = result.loc[result["FIPS"].isin(list_2012)]

    [not_avail.append(i) for i in nc_counties if i not in list(year_2017["FIPS"].unique())]

    i = 0
    while i < len(not_avail):
        result = result.append({
            "FIPS":not_avail[i],
            'year':"2017",
            "HTDD": np.nan,
            "PRCP": np.nan,
            "TAVG": np.nan,
            "TMAX": np.nan,
            "TMIN": np.nan,
        }, ignore_index=True)
        result = result.append({
            "FIPS":not_avail[i],
            'year':"2012",
            "HTDD": np.nan,
            "PRCP": np.nan,
            "TAVG": np.nan,
            "TMAX": np.nan,
            "TMIN": np.nan,
        }, ignore_index=True)
        i += 1
        
    imp = SimpleImputer(missing_values=np.nan, strategy='median')
    transformed_result = pd.DataFrame(imp.fit_transform(result))
    transformed_result.columns=result.columns
    transformed_result.index=result.index

    convert_dict = {
        "FIPS": int, 
        "year": int
    } 

    transformed_result = transformed_result.astype(convert_dict)\
        .sort_values(by=["year","FIPS"]).reset_index(drop=True)
    
    for i in ["PRCP","TAVG","TMAX","TMIN","HTDD", "CLDD"]:
        transformed_result[i]= round(transformed_result[i],2)
    return transformed_result

weather_data = get_complete_data()
weather_data.to_csv("weather_data.csv",index=False)