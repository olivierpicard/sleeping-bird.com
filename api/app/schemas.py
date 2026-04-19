from typing import Literal, Union

from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel


class _CamelModel(BaseModel):
    model_config = ConfigDict(
        alias_generator=to_camel,
        populate_by_name=True,
        serialize_by_alias=True,
        json_schema_extra={"additionalProperties": False},
    )


class NumberTracker(_CamelModel):
    """Track a numeric value within a defined range. E.g., weight, calories, pain level, steps."""

    kind: Literal["number"] = Field(description="kind of tracker")
    min: float = Field(
        description="Lower bound. E.g., 0 for weight, 1 for a 1-10 scale.", examples=[0]
    )
    max: float = Field(
        description="Upper bound. E.g., 500 daily carbs, 10 for pain levels.", examples=[500]
    )
    granularity: float = Field(
        description="Increment step. E.g., 1 for counts, 0.1 for precise weight, 0.5, 0.01, 5, 10, ...",
        examples=[1],
    )
    unit: str | None = Field(
        default=None, description="Display unit. E.g., 'kg', 'steps', 'kcal'.", examples=["kcal"]
    )
    goal: float | None = Field(
        default=None, description="Optional target value. E.g., 2000 calories.", examples=[2000]
    )


class CategorySingleTracker(_CamelModel):
    """Track a single choice from a fixed list. E.g., mood, workout type."""

    kind: Literal["categorySingle"]
    labels: list[str] = Field(
        min_length=2,
        max_length=15,
        description="Mutually exclusive options. E.g., ['Great', 'Good', 'Meh', 'Bad'].",
        examples=[["Great", "Good", "Meh", "Bad"]],
    )


class CategoryMultipleTracker(_CamelModel):
    """Track multiple choices from a fixed list. E.g., symptoms, workout muscles."""

    kind: Literal["categoryMultiple"]
    labels: list[str] = Field(
        min_length=2,
        max_length=15,
        description="Options where multiple can be selected. E.g., ['Chest', 'Legs', 'Cardio'].",
        examples=[["Chest", "Legs", "Cardio"]],
    )


class DurationTracker(_CamelModel):
    """Track an elapsed time. E.g., workout duration, sleep, meditation."""

    kind: Literal["duration"]
    granularity: Literal["ms", "s", "m", "h"] = Field(
        description="Smallest unit of input allowed. 's' allows seconds, 'm' limits to minutes/hours.",
        examples=["m"],
    )
    max_in_seconds: float = Field(
        description="Expected max duration in SECONDS.  E.g., 7200 for a 2h workout.",
        examples=[7200, 60, 1800],
    )


class BinaryTracker(_CamelModel):
    """Track a yes/no habit or event. E.g., took medication, exercised today."""

    kind: Literal["binary"]
    true_label: str = Field(
        description="E.g., 'Did it', 'Yes', 'Took Meds'.", examples=["Took Meds"]
    )
    false_label: str = Field(description="E.g., 'Missed', 'No', 'Sober'.", examples=["Missed"])


class DateTimeTracker(_CamelModel):
    """Track a point in time. E.g., bedtime, appointment."""

    kind: Literal["dateTime"]


# Tracker = Annotated[
#     NumberTracker
#     | CategorySingleTracker
#     | CategoryMultipleTracker
#     | DurationTracker
#     | BinaryTracker
#     | DateTimeTracker,
#     Field(discriminator="kind"),
# ]


class Suggestion(_CamelModel):
    metric_name: str = Field(
        description="Concise, title-cased name. E.g., 'Daily Hydration', 'Deep Sleep Duration', 'Anxiety Level'.",
        examples=["Daily Hydration"],
    )
    fit_probability: float = Field(
        ge=0,
        le=1,
        description=(
            "Confidence score [0.0 to 1.0]. Use 1.0 only if the user's intent is unambiguous (e.g., 'Track steps'). "
            "Use values < 1.0 to offer multiple perspectives for vague intents."
        ),
        examples=[0.9],
    )
    # tracker: Tracker
    tracker: Union[
        NumberTracker,
        CategorySingleTracker,
        CategoryMultipleTracker,
        DurationTracker,
        BinaryTracker,
        DateTimeTracker,
    ]


class SuggestionsSchema(_CamelModel):
    suggestions: list[Suggestion] = Field(
        min_length=1,
        max_length=3,
        description="A list of 1 to 3 tracking configurations based on the user's intent.",
    )


class GenerateResponse(_CamelModel):
    response: SuggestionsSchema


class ErrorResponse(_CamelModel):
    error: str
