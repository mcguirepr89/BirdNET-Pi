import sqlite3
import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm
from datetime import datetime
import textwrap
import matplotlib.font_manager as font_manager
from matplotlib import rcParams

userDir = os.path.expanduser('~')
conn = sqlite3.connect(userDir + '/BirdNET-Pi/scripts/birds.db')
df = pd.read_sql_query("SELECT * from detections", conn)
cursor = conn.cursor()
cursor.execute('SELECT * FROM detections WHERE Date = DATE(\'now\', \'localtime\')')

table_rows = cursor.fetchall()

# df=pd.DataFrame(table_rows)

# Convert Date and Time Fields to Panda's format
df['Date'] = pd.to_datetime(df['Date'])
df['Time'] = pd.to_datetime(df['Time'], unit='ns')


# Add round hours to dataframe
df['Hour of Day'] = [r.hour for r in df.Time]

# Create separate dataframes for separate locations
df_plt = df  # Default to use the whole Dbase

# Add every font at the specified location
font_dir = [userDir + '/BirdNET-Pi/homepage/static', '/usr/share/fonts/truetype']
for font in font_manager.findSystemFonts(font_dir):
    font_manager.fontManager.addfont(font)

# Set font family globally
db_lang = os.environ.get('DATABASE_LANG')
if db_lang == 'zh':
  rcParams['font.family'] = 'WenQuanYi Zen Hei'
  rcParams['font.sans-serif'] = ['WenQuanYi Zen Hei']
  rcParams['axes.unicode_minus'] = False               # 解决保存图像是负号—'显示为方块的问题
else:
  rcParams['font.family'] = 'Roboto Flex'

# Get todays readings
now = datetime.now()
df_plt_today = df_plt[df_plt['Date'] == now.strftime("%Y-%m-%d")]

# Set number of species to report
readings = 10

plt_top10_today = (df_plt_today['Com_Name'].value_counts()[:readings])
df_plt_top10_today = df_plt_today[df_plt_today.Com_Name.isin(plt_top10_today.index)]

if df_plt_top10_today.empty:
    exit(0)

# Set Palette for graphics
pal = "Greens"

# Set up plot axes and titles
f, axs = plt.subplots(1, 2, figsize=(10, 4), gridspec_kw=dict(width_ratios=[3, 6]), facecolor='#77C487')
plt.subplots_adjust(left=None, bottom=None, right=None, top=None, wspace=0, hspace=0)

# generate y-axis order for all figures based on frequency
freq_order = pd.value_counts(df_plt_top10_today['Com_Name']).iloc[:readings].index

# make color for max confidence --> this groups by name and calculates max conf
confmax = df_plt_top10_today.groupby('Com_Name')['Confidence'].max()
# reorder confmax to detection frequency order
confmax = confmax.reindex(freq_order)

# norm values for color palette
norm = plt.Normalize(confmax.values.min(), confmax.values.max())
colors = plt.cm.Greens(norm(confmax))

# Generate frequency plot
plot = sns.countplot(y='Com_Name', data=df_plt_top10_today, palette=colors, order=freq_order, ax=axs[0])


# Try plot grid lines between bars - problem at the moment plots grid lines on bars - want between bars
z = plot.get_ymajorticklabels()
plot.set_yticklabels(['\n'.join(textwrap.wrap(ticklabel.get_text(), 15)) for ticklabel in plot.get_yticklabels()], fontsize=10)
plot.set(ylabel=None)
plot.set(xlabel="Detections")


# Generate crosstab matrix for heatmap plot
heat = pd.crosstab(df_plt_top10_today['Com_Name'], df_plt_top10_today['Hour of Day'])

# Order heatmap Birds by frequency of occurrance
heat.index = pd.CategoricalIndex(heat.index, categories=freq_order)
heat.sort_index(level=0, inplace=True)

hours_in_day = pd.Series(data=range(0, 24))
heat_frame = pd.DataFrame(data=0, index=heat.index, columns=hours_in_day)
heat = (heat + heat_frame).fillna(0)

# Get current hour
current_hour = now.hour

# Generate heatmap plot
plot = sns.heatmap(
    heat,
    norm=LogNorm(),
    annot=True,
    annot_kws={"fontsize": 7},
    fmt="g",
    cmap=pal,
    square=False,
    cbar=False,
    linewidths=0.5,
    linecolor="Grey",
    ax=axs[1],
    yticklabels=False
)

# Set color and weight of tick label for current hour
for label in plot.get_xticklabels():
    if int(label.get_text()) == current_hour:
        label.set_color('yellow')

plot.set_xticklabels(plot.get_xticklabels(), rotation=0, size=7)



# Set heatmap border
for _, spine in plot.spines.items():
    spine.set_visible(True)

plot.set(ylabel=None)
plot.set(xlabel="Hour of Day")
# Set combined plot layout and titles
f.subplots_adjust(top=0.9)
plt.suptitle("Top 10 Last Updated: " + str(now.strftime("%Y-%m-%d %H:%M")))

# Save combined plot
userDir = os.path.expanduser('~')
savename = userDir + '/BirdSongs/Extracted/Charts/Combo-' + str(now.strftime("%Y-%m-%d")) + '.png'
plt.savefig(savename)
plt.show()
plt.close()


# Get Bottom detection frequency
plt_Bot10_today = (df_plt_today['Com_Name'].value_counts()[-readings:])
df_plt_Bot10_today = df_plt_today[df_plt_today.Com_Name.isin(plt_Bot10_today.index)]

# Set Palette for graphics
pal = "Reds"

# Set up plot axes and titles

f, axs = plt.subplots(1, 2, figsize=(10, 4), gridspec_kw=dict(width_ratios=[3, 6]), facecolor='#77C487')
plt.subplots_adjust(left=None, bottom=None, right=None, top=None, wspace=0, hspace=0)

# generate y-axis order for all figures based on frequency
freq_order = pd.value_counts(df_plt_Bot10_today['Com_Name']).iloc[-readings:].index

# make color for max confidence --> this groups by name and calculates max conf
confmax = df_plt_Bot10_today.groupby('Com_Name')['Confidence'].max()
confmax = confmax.reindex(freq_order)
# probably wrong order . . . how to sort by no. of detections ?
# norm values for color palette
norm = plt.Normalize(confmax.values.min(), confmax.values.max())
colors = plt.cm.Reds(norm(confmax))

# Generate frequency plot
plot = sns.countplot(y='Com_Name', data=df_plt_Bot10_today, palette=colors, order=freq_order, ax=axs[0])


# Try plot grid lines between bars - problem at the moment plots grid lines on bars - want between bars
z = plot.get_ymajorticklabels()
plot.set_yticklabels(['\n'.join(textwrap.wrap(ticklabel.get_text(), 15)) for ticklabel in plot.get_yticklabels()], fontsize=10)
plot.set(ylabel=None)
plot.set(xlabel="Detections")

# Generate crosstab matrix for heatmap plot

heat = pd.crosstab(df_plt_Bot10_today['Com_Name'], df_plt_Bot10_today['Hour of Day'])
# Order heatmap Birds by frequency of occurrance
heat.index = pd.CategoricalIndex(heat.index, categories=freq_order)
heat.sort_index(level=0, inplace=True)


hours_in_day = pd.Series(data=range(0, 24))
heat_frame = pd.DataFrame(data=0, index=heat.index, columns=hours_in_day)
heat = (heat + heat_frame).fillna(0)

# Generatie heatmap plot
plot = sns.heatmap(
    heat,
    norm=LogNorm(),
    annot=True,
    fmt="g",
    annot_kws={
        "fontsize": 7},
    cmap=pal,
    square=False,
    cbar=False,
    linewidths=0.5,
    linecolor="Grey",
    ax=axs[1],
    yticklabels=False)
plot.set_xticklabels(plot.get_xticklabels(), rotation=0, size=7)

# Set heatmap border
for _, spine in plot.spines.items():
    spine.set_visible(True)

plot.set(ylabel=None)
plot.set(xlabel="Hour of Day")
# Set combined plot layout and titles
f.subplots_adjust(top=0.9)
plt.suptitle("Bottom 10 Last Updated: " + str(now.strftime("%Y-%m-%d %H:%M")))

# Save combined plot
savename = userDir + '/BirdSongs/Extracted/Charts/Combo2-' + str(now.strftime("%Y-%m-%d")) + '.png'
plt.savefig(savename)
plt.show()
plt.close()
