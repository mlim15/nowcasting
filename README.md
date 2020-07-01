# MAPLE Nowcasting

This repository contains a Flutter app for Android and iOS that facilitates access to [nowcasting data](https://radar.mcgill.ca/imagery/nowcasting.html) provided by [McGill University](https://mcgill.ca/)'s J.S. Marshall Radar Observatory.

## What is Nowcasting

Put simply, [nowcasting](https://en.wikipedia.org/wiki/Nowcasting_(meteorology)) is a practice which aims to accurately extrapolate very-near-future data using past trends. In meteorology, nowcasting algorithms have been developed to predict rainfall 2-6 hours in advance. McGill's MAPLE algorithm does so by extrapolation from recent radar composite imagery and wind directions, and this data is generously calculated and provided by the university for central Canada and the US northeast, updated every 10 minutes.

## Todo

Most of the planned features for the app are implemented, except for:
- Reordering entries on the forecast screen
- A map-based location picker to change locations without having to type in coordinates
- On-device notifications for chosen forecast locations
- Extra layers (e.g. temperature, wind barbs) on the map screen
- The info/credits screen
