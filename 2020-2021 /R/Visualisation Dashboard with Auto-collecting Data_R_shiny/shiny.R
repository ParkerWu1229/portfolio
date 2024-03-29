# Set up necessary packages
library(shinydashboard)
library(ggplot2)
library(shiny)
library(leaflet)
library(dplyr)
library(shinyWidgets)
library(stringr)
library(plotly)
library(ggiraph)
library(RColorBrewer)

# Load the data from part C
data <- read.csv("restaurants.data.csv", stringsAsFactors = TRUE)

# Change the necessary column back to character type to output in options later
data$LocalAuthorityName<- as.character(data$LocalAuthorityName)
data$RatingValue<- as.character(data$RatingValue)
data$BusinessType<- as.character(data$BusinessType)

# Clean data to visualize in the dashboard
table <- data
table$Address <- paste(table$AddressLine1,table$AddressLine2,table$AddressLine3,table$AddressLine4)
table$Address <- str_replace_all(table$Address, "NA","")
table <- table %>% relocate(Address, .before = PostCode)
drop <- c("FHRSID","LocalAuthorityBusinessID","BusinessTypeID","LocalAuthorityCode","NewRatingPending","Longitude","Latitude","nil","RightToReply","AddressLine1","AddressLine2","AddressLine3","AddressLine4","LocalAuthorityWebSite","LocalAuthorityEmailAddress")
table <- table[,!names(table) %in% drop]

# Get the list to put in the picker and selection input
city_list <- unique(data$LocalAuthorityName)
city_list_scot <- filter(data, SchemeType=="FHIS")%>%select(LocalAuthorityName)%>%unique()
city_list_other <- filter(data, SchemeType=="FHRS")%>%select(LocalAuthorityName)%>%unique()
rating_list <- unique(data$RatingValue)
business_type_list <- unique(data$BusinessType)
area_list <- unique(data$SchemeType)

# Change the name of the scheme type to the corresponding area
area_list<-c("Scotland","England, Northern Ireland and Wales")
data$SchemeType <- str_replace_all(data$SchemeType,"FHIS","Scotland")
data$SchemeType <- str_replace_all(data$SchemeType,"FHRS","England, Northern Ireland and Wales")
table$SchemeType <- str_replace_all(table$SchemeType,"FHIS","Scotland")
table$SchemeType <- str_replace_all(table$SchemeType,"FHRS","England, Northern Ireland and Wales")


# Header
header <- dashboardHeader(
  title = "Food Hygiene Data",
  
  # A little surprise to professor
  dropdownMenu(
    type="messages",
    messageItem(
      from="Group 12",
      message = "We love you, Nikos!",
      icon=icon(name="heart")
    )
  ))



# Sidebar
sidebar <- dashboardSidebar(
  sidebarMenu(
    
    # Item for Map
    menuItem("Map",
             tabName="map",
             icon=icon("map-marked-alt"),
             badgeLabel = "new", 
             badgeColor = "green"),
    # Item for Table
    menuItem("Table",
             tabName="table",
             icon=icon("table")),
    
    # Item for Graph
    menuItem("Graph",
             tabName="graph",
             icon=icon("chart-line"))
  )
)

# Body
body <- dashboardBody(
  tabItems(
 
   # Body for Map
    tabItem(
      tabName = "map",
      fluidRow(
      
      # First input filter
        column(width = 12, align="center",pickerInput("area_map", label = h3("Select Locations"), choices = area_list, multiple=TRUE, selected=c("Scotland","England, Northern Ireland and Wales"))))
        
      # Second input filter (choices depend on the choice for the first area input)
      , fluidRow(
        column(width=4,align="center",uiOutput("secondSelection_map")),
        
      # Third input filter (choices depend on the choice for the first and second city input)
        column(width=4, align="center",uiOutput("thirdSelection_map")),
        
      # Fourth input filter (choices depend on the choice for the first, second, and third input)
        column(width=4,align="center",uiOutput("fourthSelection_map")))
      ,
      
      # Map Output
      fluidRow(column(width = 12,align="center", leafletOutput("map"),htmlOutput("mapdescription"))),
        # Hide the error message when user doesn't choose any option
      tags$style(type = "text/css",
                 ".shiny-output-error { visibility: hidden; }",
                 ".shiny-output-error:before { visibility: hidden; }"))
    
    # Body for Table
    , tabItem(
      tabName = "table"
      , fluidRow(
      
      # First input filter
        column(width = 12, align="center",pickerInput("area_table", label = h3("Select Locations"), choices = area_list, multiple=TRUE, selected=c("Scotland","England, Northern Ireland and Wales"))))
     
      # Second input filter (choices depend on the choice for the first area input)
      , fluidRow(
        column(width=4,align="center",uiOutput("secondSelection_table")),
      
      # Third input filter (choices depend on the choice for the first and second city input)
        column(width=4, align="center",uiOutput("thirdSelection_table")),
        
      # Fourth input filter (choices depend on the choice for the first, second, and third input)
        column(width=4,align="center",uiOutput("fourthSelection_table")))
      
      # Callout table and add scroll at the bottom of table to see all columns
      , fluidRow(
        column(width = 12,
               box(
                 width = NULL
                 , title = "Food Hygiene Data Table"
                 , div(dataTableOutput("table"))
               ))
      ))
    
    # Body for Graph
    , tabItem(
      tabName="graph",
      fluidRow(
        
        # First input filter
        column(width = 12, align="center",pickerInput("area_plot", label = h3("Select Locations"), choices = area_list, multiple=TRUE, selected=c("Scotland","England, Northern Ireland and Wales")))
      )
      ,fluidRow(
        
        # Second input filter (choices depend on the choice for the first area input)
        column(width=6,align="center",uiOutput("secondSelection_plot"))
        
        # Third input filter (choices depend on the choice for the first and second city input)
        ,column(width=6, align="center",uiOutput("thirdSelection_plot")))
      , fluidRow(
        
        # Bar Chart for count of overall rating
        column(width = 6, plotlyOutput("ratingFilter_plot"))
        
        # Value Box to show the number of restaurants in the selected area
        ,column(width = 6, align="center",valueBoxOutput("restaurant_box"))
      )
      
        # Bar Chart for count by business type
      , fluidRow(
        column(width = 12, plotlyOutput("rating_column_total")))
      )

      
    )

  
  # UI Style
  , tags$head(tags$style(HTML('
  
         /* list color */
         .skin-blue .main-sidebar {
         background-color: black;
         }
        
         /* bottom color */
         .skin-blue .main-sidebar
         .sidebar
         .sidebar-menu
         .active a{
         background-color: white;}
         
         /* value box size */
         .small-box {height: 400px; width: 500px;text-align:center}
         
        '))
  )
)



# SERVER
server <- function(input, output){
  
  # MAP
  output$map <- renderLeaflet({
    
    # filter data by user's selection
    filter_data <- filter(data, LocalAuthorityName %in% input$city_map & SchemeType %in% input$area_map & RatingValue %in% input$rating_map & BusinessType %in% input$business_type_map)
    leaflet() %>%
      addTiles() %>%  
      addMarkers(
        
        # Show the count when too many data in a specific area
        clusterOptions = markerClusterOptions(),
        
        # Put data on the map according to the longitude and latitude
        lng = filter_data$Longitude, 
        lat = filter_data$Latitude,
        
        # show the label when you click one restaurant icon on the map
        popup = paste("Restaurant Name: ",filter_data$BusinessName,"<br>",
                      "Postal Code: ",filter_data$PostCode,"<br>",
                      "Rating Value: ",filter_data$RatingValue))
  })
  
  
    # Map - Change the choices for the second selection on the basis of the input to the first selection
  output$secondSelection_map <- renderUI({
    choice_second_list_map <- unique(data$LocalAuthorityName[which(data$SchemeType %in% input$area_map)])
    pickerInput(inputId = "city_map", choices = choice_second_list_map, selected = choice_second_list_map[1], multiple=TRUE,
                label = "Choose the city for which you want to see:")
  })
  
   # Map - Change the choices for the third selection on the basis of the input to the first and second selections
  output$thirdSelection_map <- renderUI({
    choice_third_list_map <- unique(data$RatingValue[data$SchemeType %in% input$area_map & data$LocalAuthorityName %in% input$city_map])
    pickerInput(inputId = "rating_map", choices = choice_third_list_map, selected = choice_third_list_map, multiple=TRUE,
                label = "You want to explore which rating:")
  })
  
    # Map - Change the choices for the fourth selection on the basis of the input to the first and second and third selections
  output$fourthSelection_map <- renderUI({
    choice_fourth_list_map <- unique(data$BusinessType[data$SchemeType %in% input$area_map & data$LocalAuthorityName %in% input$city_map & data$RatingValue %in% input$rating_map])
    pickerInput(inputId = "business_type_map", choices = choice_fourth_list_map, selected = choice_fourth_list_map[1], multiple=TRUE,
                label = "Choose a business type:")
  })
  
    #Map - State remarks to help users understand how to use the map
  output$mapdescription <- renderUI({
    HTML(paste("Remark1 : The number you see for each point is number of restaurants for the nearby area. Please click on the cluster to investigate further. The color indicates density of restaurants from red = highest density followed by orange, yellow and green, respectively.", "Remark2 : You can choose more than one option", sep="<br/>"))
  })
  
  # TABLE
  output$table <- renderDataTable({
    
    # filter data by user's selection
    table <- filter(table, LocalAuthorityName %in% input$city_table, SchemeType %in% input$area_table, RatingValue %in% input$rating_table, BusinessType %in% input$business_type_table)
  }
    # Add Scroll Bar
  ,options = list(scrollX = TRUE))
   
    # Table - Change the choices for the second selection on the basis of the input to the first selection
  output$secondSelection_table <- renderUI({
    choice_second_list_table <- unique(data$LocalAuthorityName[which(data$SchemeType %in% input$area_table)])
    pickerInput(inputId = "city_table", choices = choice_second_list_table, selected = choice_second_list_table[1], multiple=TRUE,
                label = "Choose the city for which you want to see:")
  })
  
    # Table - Change the choices for the third selection on the basis of the input to the first and second selections
  output$thirdSelection_table <- renderUI({
    choice_third_list_table <- unique(data$RatingValue[data$SchemeType %in% input$area_table & data$LocalAuthorityName %in% input$city_table])
    pickerInput(inputId = "rating_table", choices = choice_third_list_table, selected = choice_third_list_table, multiple=TRUE,
                label = "You want to explore which rating:")
  })
  
   # Table - Change the choices for the fourth selection on the basis of the input to the first and second and third selections
  output$fourthSelection_table <- renderUI({
    choice_fourth_list_table <- unique(data$BusinessType[data$SchemeType %in% input$area_table & data$LocalAuthorityName %in% input$city_table & data$RatingValue %in% input$rating_table])
    pickerInput(inputId = "business_type_table", choices = choice_fourth_list_table, selected = choice_fourth_list_table[1], multiple=TRUE,
                label = "Choose a business type:")
  })
  
  # GRAPH
  
   # Chart 1.1 - Number of restaurant by Business Type
  output$restaurant_by_type <- renderPlotly({
    
    # filter data by user's selection
    g1 <- ggplot(data %>% filter(LocalAuthorityName %in% input$city_plot & SchemeType %in% input$area_plot),aes(x = BusinessType)) + geom_bar(aes(fill = (BusinessType))) 
    + coord_flip()
    ggplotly(g1)

  })
  
   # Chart 1.2 - ValueBox number of restaurant
  output$restaurant_box <- renderValueBox({
    
    # filter data by user's selection
    data_file <- filter(data,LocalAuthorityName %in% input$city_plot & SchemeType %in% input$area_plot & BusinessType %in% input$business_type_plot)
    
    # Count the number of the restaurant
    n_restaurant <-length(unique(data_file$BusinessName))
    
    # Output as a value box
    valueBox(value = tags$p( n_restaurant,style = "font-size: 300%;"), subtitle = tags$p("Number of Restaurant in Chosen Cities and Types",style = "font-size: 160%;"),
             icon = icon("store", class="fa-3x"))
  })
  
    # Chart 2 - Rating - Overall
  output$ratingFilter_plot <- renderPlotly({
    data$RatingValue<- as.factor(data$RatingValue)
   
     # filter data by user's selection
    g1 <- ggplot(data %>% filter(LocalAuthorityName %in% input$city_plot & SchemeType %in% input$area_plot & BusinessType %in% input$business_type_plot),aes(x=RatingValue)) + geom_bar(aes(y = (..count..)/sum(..count..), text = paste("Percentage:",round(((..count..)/sum(..count..)*100),2),"%")),fill="skyblue",alpha=0.8)+ scale_y_continuous(labels = scales::percent) +theme(plot.title = element_text(lineheight=.8, face="bold",size=10),axis.text.x =element_text(angle=45,hjust = 1, size=8)) + ggtitle("Percentage of restaurants in chosen cities and types") + xlab("Rating Value") + ylab("Percent (%)")
    ggplotly(g1, tooltip = c("x","text"))
    
  })
    # Chart 3 - Rating by Business Type 
  output$rating_column_total <- renderPlotly({
    data$RatingValue<- as.factor(data$RatingValue)
  
      # filter data by user's selection
    g2 <- ggplot(data %>% filter(LocalAuthorityName %in% input$city_plot & SchemeType %in% input$area_plot),aes(x = BusinessType)) + geom_bar(aes(fill = (RatingValue), position = "fill")) + coord_flip() + ggtitle("Number of restaurants of all business type for each city") + labs(fill = "Rating Value")
    ggplotly(g2, tooltip = c("x","y","fill"))
  })
  
  # Selection Input of city, based on area chosen, for user for others
  output$secondSelection_plot <- renderUI({
    choice_second_list_plot <- unique(data$LocalAuthorityName[which(data$SchemeType %in% input$area_plot)])
    pickerInput(inputId = "city_plot", choices = choice_second_list_plot, selected = choice_second_list_plot[1], multiple = TRUE,
                label = "Choose the city for which you want to see:")
  })
  
  # Selection Input of business type, based on city and area chosen, for user for others
  output$thirdSelection_plot <- renderUI({
    choice_third_list_plot <- unique(data$BusinessType[data$SchemeType %in% input$area_plot & data$LocalAuthorityName %in% input$city_plot])
    pickerInput(inputId = "business_type_plot", choices = choice_third_list_plot, selected = choice_third_list_plot[1], multiple = TRUE,
                label = "Choose a business type:")
  })
  
  
}

# UI
ui <- dashboardPage(
  header=header, 
  sidebar=sidebar, 
  body=body,
  skin="black")

# Run
shinyApp(ui,server)

