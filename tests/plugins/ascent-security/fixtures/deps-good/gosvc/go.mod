module example.com/gosvc

go 1.23

require (
	github.com/google/uuid v1.6.0
)

replace example.com/local => ./local
